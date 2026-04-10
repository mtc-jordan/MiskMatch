"use client";

import clsx from "clsx";

interface Props {
  page: number;
  total: number;
  pageSize: number;
  onChange: (page: number) => void;
}

export default function Pagination({ page, total, pageSize, onChange }: Props) {
  const totalPages = Math.ceil(total / pageSize);
  if (totalPages <= 1) return null;

  return (
    <div className="flex items-center justify-between mt-4 text-sm">
      <p className="text-gray-500">
        Showing {(page - 1) * pageSize + 1}–{Math.min(page * pageSize, total)} of {total}
      </p>
      <div className="flex gap-1">
        <button
          onClick={() => onChange(page - 1)}
          disabled={page <= 1}
          className={clsx("px-3 py-1 rounded border", page <= 1 ? "text-gray-300 cursor-not-allowed" : "hover:bg-gray-100")}
        >
          Prev
        </button>
        <button
          onClick={() => onChange(page + 1)}
          disabled={page >= totalPages}
          className={clsx("px-3 py-1 rounded border", page >= totalPages ? "text-gray-300 cursor-not-allowed" : "hover:bg-gray-100")}
        >
          Next
        </button>
      </div>
    </div>
  );
}
