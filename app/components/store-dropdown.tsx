"use client";

import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import { ChevronDown } from "lucide-react";

export type StoreDropdownOption = { value: string; label: string };

export function StoreDropdown({
  id,
  label,
  value,
  options,
  onChange,
  compact = false,
  leadingIcon,
}: {
  id: string;
  label: string;
  value: string;
  options: StoreDropdownOption[];
  onChange: (value: string) => void;
  compact?: boolean;
  leadingIcon?: ReactNode;
}) {
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const listboxRef = useRef<HTMLDivElement>(null);
  const selectedIndex = Math.max(0, options.findIndex((option) => option.value === value));
  const selectedOption = options[selectedIndex];

  useEffect(() => {
    if (!open) return;
    function closeWhenClickingOutside(event: PointerEvent) {
      if (!dropdownRef.current?.contains(event.target as Node)) setOpen(false);
    }
    document.addEventListener("pointerdown", closeWhenClickingOutside);
    return () => document.removeEventListener("pointerdown", closeWhenClickingOutside);
  }, [open]);

  function choose(option: StoreDropdownOption) {
    onChange(option.value);
    setOpen(false);
    triggerRef.current?.focus();
  }

  function handleListKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const lastIndex = options.length - 1;
    if (event.key === "ArrowDown" || event.key === "ArrowUp" || event.key === "Home" || event.key === "End") {
      event.preventDefault();
      setActiveIndex((current) => {
        if (event.key === "Home") return 0;
        if (event.key === "End") return lastIndex;
        return Math.min(lastIndex, Math.max(0, current + (event.key === "ArrowDown" ? 1 : -1)));
      });
      return;
    }
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      const option = options[activeIndex];
      if (option) choose(option);
    } else if (event.key === "Escape") {
      event.preventDefault();
      setOpen(false);
      triggerRef.current?.focus();
    }
  }

  return (
    <div className={`store-filter-dropdown${compact ? " store-filter-dropdown-compact" : ""}`} ref={dropdownRef} data-open={open ? "true" : "false"}>
      <button
        ref={triggerRef}
        type="button"
        className="store-filter-dropdown-trigger"
        aria-label={`${label}، ${selectedOption?.label ?? ""}`}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={`${id}-options`}
        onClick={() => {
          if (!open) setActiveIndex(selectedIndex);
          setOpen((current) => !current);
        }}
        onKeyDown={(event) => {
          if (!open && event.key === "ArrowDown") {
            event.preventDefault();
            setActiveIndex(selectedIndex);
            setOpen(true);
            window.requestAnimationFrame(() => listboxRef.current?.focus());
          } else if (open && event.key === "Escape") {
            event.preventDefault();
            setOpen(false);
          }
        }}
      >
        {leadingIcon && <span className="store-filter-dropdown-leading-icon">{leadingIcon}</span>}
        <span className="store-filter-dropdown-label">{selectedOption?.label ?? "انتخاب کنید"}</span>
        <ChevronDown size={16} aria-hidden="true" />
      </button>
      <div
        ref={listboxRef}
        className="store-filter-dropdown-options"
        id={`${id}-options`}
        role="listbox"
        aria-label={label}
        aria-activedescendant={`${id}-option-${activeIndex}`}
        tabIndex={open ? 0 : -1}
        hidden={!open}
        onKeyDown={handleListKeyDown}
      >
        {options.map((option, index) => (
          <div
            id={`${id}-option-${index}`}
            key={`${id}-${option.value}`}
            role="option"
            aria-selected={option.value === value}
            className={`store-filter-dropdown-option${activeIndex === index ? " is-active" : ""}`}
            onMouseEnter={() => setActiveIndex(index)}
            onClick={() => choose(option)}
          >
            {option.label}
          </div>
        ))}
      </div>
    </div>
  );
}
