"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();

  useEffect(() => {
    // No auth required — redirect to home
    router.push("/");
  }, [router]);

  return <div>Redirecting...</div>;
}
