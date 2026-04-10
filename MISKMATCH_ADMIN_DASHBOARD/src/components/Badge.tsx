"use client";

import clsx from "clsx";

const colors: Record<string, string> = {
  active: "bg-emerald-100 text-emerald-800",
  pending: "bg-amber-100 text-amber-800",
  banned: "bg-red-100 text-red-800",
  suspended: "bg-orange-100 text-orange-800",
  admin: "bg-purple-100 text-purple-800",
  user: "bg-gray-100 text-gray-700",
  mutual: "bg-blue-100 text-blue-800",
  approved: "bg-emerald-100 text-emerald-800",
  nikah: "bg-gold-100 text-gold-800",
  closed: "bg-gray-100 text-gray-600",
  blocked: "bg-red-100 text-red-700",
  resolved: "bg-emerald-100 text-emerald-800",
  dismissed: "bg-gray-100 text-gray-600",
  flagged: "bg-red-100 text-red-700",
};

export default function Badge({ value }: { value: string }) {
  const lower = value.toLowerCase();
  return (
    <span className={clsx("inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium", colors[lower] || "bg-gray-100 text-gray-700")}>
      {value}
    </span>
  );
}
