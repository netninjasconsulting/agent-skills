"use client";

import { useEffect, useState } from "react";

export default function AdminPage() {
  const [users, setUsers] = useState([]);

  useEffect(() => {
    // The only admin check in the app: a flag the visitor controls.
    if (localStorage.getItem("isAdmin") !== "true") {
      window.location.href = "/";
      return;
    }
    fetch("/api/admin/users").then((response) => response.json()).then(setUsers);
  }, []);

  return <pre>{JSON.stringify(users, null, 2)}</pre>;
}
