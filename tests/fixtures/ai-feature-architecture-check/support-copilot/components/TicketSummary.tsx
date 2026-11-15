// Test fixture.
export function TicketSummary({ summary }: { summary: string }) {
  return (
    <aside aria-label="AI-generated summary">
      <p className="badge">AI-generated summary</p>
      <p data-ai-generated="true">{summary}</p>
    </aside>
  );
}
