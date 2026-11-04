"use client";

import { useId, useRef, useState } from "react";
import { MAX_TAG_LENGTH, MAX_TAGS, tagSchema, tagsSchema } from "@/lib/submissions/validation";

type EditableTag = { id: number; value: string };

export function TagEditor({
  initialTags,
  onChange,
  onPendingChange,
}: {
  initialTags: readonly string[];
  onChange: (tags: string[]) => void;
  onPendingChange: (value: string) => void;
}) {
  const id = useId();
  const nextId = useRef(initialTags.length);
  const [tags, setTags] = useState<EditableTag[]>(initialTags.map((value, index) => ({ id: index, value })));
  const [newTag, setNewTag] = useState("");
  const [error, setError] = useState("");

  function updateTags(updated: EditableTag[]) {
    setTags(updated);
    setError("");
    onChange(updated.map((tag) => tag.value));
  }

  function addTag() {
    const parsed = tagSchema.safeParse(newTag);
    if (!parsed.success) {
      setError(parsed.error.issues[0].message);
      return;
    }
    const result = tagsSchema.safeParse([...tags.map((tag) => tag.value), parsed.data]);
    if (!result.success) {
      setError(result.error.issues[0].message);
      return;
    }
    updateTags([...tags, { id: nextId.current++, value: parsed.data }]);
    setNewTag("");
    onPendingChange("");
  }

  return (
    <fieldset className="mt-8 min-w-0">
      <legend className="text-lg font-semibold">Make the tags your own</legend>
      <p id={`${id}-help`} className="mt-2 text-sm leading-relaxed text-stone-600">
        These are illustrative suggestions. Edit or remove any of them, or add your own.
        You can leave tags empty. Up to {MAX_TAGS} tags, {MAX_TAG_LENGTH} characters each.
      </p>
      <ul className="mt-4 space-y-3">
        {tags.map((tag, index) => (
          <li key={tag.id} className="flex items-center gap-3">
            <label htmlFor={`${id}-${tag.id}`} className="sr-only">Edit tag {index + 1}</label>
            <input id={`${id}-${tag.id}`} value={tag.value} maxLength={MAX_TAG_LENGTH} aria-describedby={`${id}-help`} onChange={(event) => updateTags(tags.map((item) => item.id === tag.id ? { ...item, value: event.target.value } : item))} className="min-w-0 flex-1 rounded-lg border border-stone-300 bg-white px-3 py-3 text-base" />
            <button type="button" onClick={() => updateTags(tags.filter((item) => item.id !== tag.id))} aria-label={`Remove tag ${index + 1}${tag.value ? `: ${tag.value}` : ""}`} className="min-h-11 shrink-0 cursor-pointer rounded-lg px-3 text-sm font-medium text-stone-600 hover:bg-stone-100 hover:text-stone-900">Remove</button>
          </li>
        ))}
      </ul>
      {tags.length === 0 && <p className="mt-4 text-sm text-stone-600">No tags yet. Add one if you like.</p>}
      <div className="mt-5">
        <label htmlFor={`${id}-new`} className="mb-2 block text-sm font-medium">New tag</label>
        <div className="flex gap-3">
          <input id={`${id}-new`} value={newTag} maxLength={MAX_TAG_LENGTH} aria-invalid={error ? true : undefined} aria-describedby={error ? `${id}-help ${id}-error` : `${id}-help`} onChange={(event) => { setNewTag(event.target.value); onPendingChange(event.target.value); setError(""); }} onKeyDown={(event) => { if (event.key === "Enter" && !event.nativeEvent.isComposing) { event.preventDefault(); addTag(); } }} placeholder="For example, Syrian folk" className="min-w-0 flex-1 rounded-lg border border-stone-300 bg-white px-3 py-3 text-base" />
          <button type="button" onClick={addTag} className="min-h-11 cursor-pointer rounded-lg border border-teal-900 px-4 text-sm font-medium text-teal-900 hover:bg-teal-50">Add tag</button>
        </div>
      </div>
      {error && <p id={`${id}-error`} role="alert" className="mt-3 text-sm text-red-800">{error}</p>}
    </fieldset>
  );
}
