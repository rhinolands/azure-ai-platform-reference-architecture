# Lab — RAG security trimming on Azure (retrieval under the user's identity)

A hands-on lab behind the **Retrieval** row of the [reference architecture](../../README.md). The point it proves: in an enterprise RAG system the dangerous part isn't the model, it's that **the index will happily return a document to someone who should never see it.** The fix is to run retrieval under the querying user's identity, so access is *enforced in the path*, not *asserted by the app*.

Reuse-first: rather than hand-build, this deploys Microsoft's maintained reference **[`Azure-Samples/azure-search-openai-demo`](https://github.com/Azure-Samples/azure-search-openai-demo)**, ingests documents, queries them, then turns on access control and proves it end to end. This writeup is the reproducible runbook plus the real failure modes hit along the way — the parts a happy-path demo skips.

> Environment: a disposable dev tenant with synthetic/sample documents only. No customer data. All resource names, tenant IDs, and identities below are placeholders.

---

## 1. The full RAG pipeline (baseline)

Deployed via `azd up`. The stack, and what each piece is:

| Component | Azure service | Role |
|---|---|---|
| Blob Storage | Storage account | raw documents |
| Parse/layout | **Azure AI Document Intelligence** | PDF → text + structure |
| Embeddings + generation | **Azure OpenAI** (`text-embedding-3-large` + a chat model) | vectors + grounded answers |
| Index + retrieval | **Azure AI Search** (hybrid + semantic ranker) | vector + keyword search, re-ranked |
| Orchestration | **Azure AI Foundry** project | catalog + eval surface |
| App host | **Azure Container Apps** | the chat backend |
| Observability | **App Insights / Log Analytics** | queries, chunks, scores, citations |

Ingestion pipeline: **parse → chunk → embed → index**. Every step authenticates with **managed identity (passwordless)** — no connection strings, no keys. That "identity in the path" property is what the security-trimming step builds on.

What the request trace shows (worth internalizing):
- **Two LLM calls per question** — one to rewrite the question into a search query, one to answer grounded on retrieved chunks.
- **Confidence floor** — each chunk carries a reranker score (0–4). A minimum-score threshold drops weak chunks *before* the model, so the app says "I don't know" instead of hallucinating.
- **Anti-hallucination is the system prompt** — "answer only from the sources, cite them, otherwise say you don't know." Two layers: the reranker floor removes weak context, the prompt forbids inventing after.

## 2. Security trimming (the actual lab)

Baseline retrieval has no access control: chunk ACL fields are empty and `use_query_source_authorization` is `false` — every user can retrieve every document. Turn it on:

```bash
azd env set AZURE_USE_AUTHENTICATION true
azd env set AZURE_ENFORCE_ACCESS_CONTROL true
azd env set AZURE_ENABLE_GLOBAL_DOCUMENT_ACCESS true   # docs with NO ACL stay visible to all
azd up
```

This adds a login UI, creates the Entra app registrations for sign-in, and turns on the identity filter in retrieval. Then lock one document to a group and leave the rest global:

```bash
# restrict a document to a specific Entra group (by object id)
python ./scripts/manageacl.py -v --acl-type groups --acl-action add \
  --acl <GROUP_OBJECT_ID> \
  --url https://<storage-account>.blob.core.windows.net/content/<doc>.pdf

# a doc stamped with the "all" global-access marker stays visible to everyone —
# remove it so ONLY the group can retrieve the doc
python ./scripts/manageacl.py -v --acl-type groups --acl-action remove --acl all \
  --url https://<storage-account>.blob.core.windows.net/content/<doc>.pdf
```

**The proof:** ask the same question that would surface that document, as two identities.
- A user **in** the group → the document is retrieved and cited.
- A user **outside** the group → the document is not retrieved. It never enters the candidate set. The answer omits it or says it doesn't know.

One ACL value flips a document between visible and trimmed for the same query. That is security trimming: access enforced at retrieval by the caller's identity, deny-by-default.

## 3. The real failure modes (what a demo hides)

Every one of these cost time and is worth knowing before you hit it in production:

1. **RBAC data-plane propagation lag.** A fresh keyless Search service (`DisableLocalAuth: true`) rejects the ingestion job on the first pass — the role assignment hasn't propagated to the data plane yet. Retry after a minute; it succeeds.
2. **Stale local dedup state.** After a teardown, leftover `.md5` files make the ingester skip every file → an empty index → "0 documents found" at ACL time. Delete the local `.md5` state and re-ingest.
3. **CLI on the wrong subscription.** The classic CLI and the deployment CLI can point at different subscriptions → a "resource not found" red herring. Pin the subscription explicitly.
4. **The global-access marker.** With global access on, every doc is stamped with an "all" marker — so a doc looks "restricted" but is still world-visible until you remove that marker. Restriction = add the group **and** remove "all".
5. **Half-finished provision.** If `azd up` dies at the post-provision step, the backend never fully deploys (blank URL). Finish it with `azd deploy`.
6. **Guest / B2B identity.** A guest user's token carries their home tenant as issuer. Object ids differ per tenant — know which identity the app actually sees.
7. **No `groups` claim in the token.** Entra doesn't emit group claims by default. If the app sees no groups, a legitimate member is **correctly** denied (deny-by-default). Production fix: configure the groups optional-claim or a Graph lookup. This is the gap that silently breaks "why can't my authorized user see the doc."
8. **Retrieval relevance ≠ access control.** A document can be absent because it was out-ranked *or* because it was trimmed. To test access you must use a query where the doc *would* rank — otherwise you're proving nothing.
9. **The ACL toggle is the clean proof.** Visibility flips on a single field, independent of the group-claim question. Toggling one ACL value (add/remove the group or the "all" marker) demonstrates trimming deterministically.

## Talk track (the one-liner)

> The dangerous part of enterprise RAG isn't the model, it's that the index will hand a document to whoever asks. So retrieval runs under the querying user's identity — documents carry ACLs, and the search is trimmed by the caller's group membership, deny-by-default. Same question, a user in the group gets the document, a user outside it doesn't, and the restricted chunk never enters the candidate set. Identity is enforced in the retrieval path, not asserted by the app.

## Where this sits in the reference architecture

This lab is the **Retrieval** and **Identity** rows made concrete: RAG over vector search, under Entra identity, least-privilege, deny-by-default. The same principle — *enforce in the path, don't assert in the app* — is what the [agent ↔ LLM gateway](../../README.md#the-agent--llm-security-model) applies to tool calls and model access.
