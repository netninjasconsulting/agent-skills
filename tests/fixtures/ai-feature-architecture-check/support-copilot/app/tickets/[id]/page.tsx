// Test fixture.
"use client";

import { useState } from "react";
import { DraftReply } from "../../../components/DraftReply";
import { TicketSummary } from "../../../components/TicketSummary";

export default function TicketPage({ params }: { params: { id: string } }) {
  const [summary, setSummary] = useState("");
  const [draft, setDraft] = useState("");

  async function summarise() {
    const response = await fetch("/api/summarise", { method: "POST", body: JSON.stringify({ ticketId: params.id }) });
    setSummary((await response.json()).summary);
  }

  async function draftReply(tenantId: string, embedding: number[]) {
    const response = await fetch("/api/draft-reply", {
      method: "POST",
      body: JSON.stringify({ ticketId: params.id, tenantId, embedding }),
    });
    setDraft((await response.json()).draft);
  }

  return (
    <main>
      <button onClick={summarise}>Summarise this ticket</button>
      <button onClick={() => draftReply(window.localStorage.getItem("tenant") ?? "", [])}>Draft a reply</button>
      {summary && <TicketSummary summary={summary} />}
      {draft && <DraftReply draft={draft} />}
    </main>
  );
}
