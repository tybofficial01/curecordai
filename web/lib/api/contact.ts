import { apiFetch } from "@/lib/api/client";

export function submitContactMessage(body: { name: string; email: string; message: string }) {
  return apiFetch<{ message: string }>("/contact", { method: "POST", body });
}
