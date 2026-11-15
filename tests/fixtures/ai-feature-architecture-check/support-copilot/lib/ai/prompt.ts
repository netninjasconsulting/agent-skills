// Test fixture.
export const PROMPT_VERSION = "draft-reply-v7";

type Customer = { id: string; name: string; email: string; phone: string; address: string; plan: string };

export function buildDraftPrompt(customer: Customer, ticketBody: string, context: { body: string }[]) {
  // The whole customer record goes into the prompt.
  return [
    "You are a support agent. Draft a reply to the ticket below.",
    `Customer record: ${JSON.stringify(customer)}`,
    `Ticket: ${ticketBody}`,
    `Context:\n${context.map((doc) => doc.body).join("\n---\n")}`,
    "If the customer is owed money, call the issue_refund tool.",
  ].join("\n\n");
}
