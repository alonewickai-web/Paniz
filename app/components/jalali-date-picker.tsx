"use client";

import { useMemo, useState } from "react";
import { ChevronDown, ChevronLeft, ChevronRight } from "lucide-react";
import { jalaaliMonthLength, toGregorian, toJalaali } from "jalaali-js";

const months = ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"];
const weekdays = ["ش", "ی", "د", "س", "چ", "پ", "ج"];
const fa = new Intl.NumberFormat("fa-IR");

function isoDate(year: number, month: number, day: number) {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}

function parseIso(value: string | null) {
  const match = value?.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  return { jy: Number(match[1]), jm: Number(match[2]), jd: Number(match[3]) };
}

export function JalaliDatePicker({ value, onChange, label = "تاریخ تولد" }: { value: string; onChange: (value: string) => void; label?: string }) {
  const current = useMemo(() => toJalaali(new Date()), []);
  const selected = parseIso(value);
  const [open, setOpen] = useState(false);
  const [year, setYear] = useState(selected?.jy ?? current.jy);
  const [month, setMonth] = useState(selected?.jm ?? current.jm);
  const firstWeekday = useMemo(() => {
    const gregorian = toGregorian(year, month, 1);
    return (new Date(gregorian.gy, gregorian.gm - 1, gregorian.gd).getDay() + 1) % 7;
  }, [month, year]);
  const days = useMemo(() => Array.from({ length: jalaaliMonthLength(year, month) }, (_, index) => index + 1), [month, year]);
  const labelValue = selected ? `${fa.format(selected.jd)} ${months[selected.jm - 1]} ${fa.format(selected.jy)}` : "انتخاب از تقویم";

  function moveMonth(delta: number) {
    const nextMonth = month + delta;
    const nextYear = year + (nextMonth > 12 ? 1 : nextMonth < 1 ? -1 : 0);
    const normalizedMonth = nextMonth > 12 ? 1 : nextMonth < 1 ? 12 : nextMonth;
    if (nextYear > current.jy || (nextYear === current.jy && normalizedMonth > current.jm)) return;
    setYear(nextYear); setMonth(normalizedMonth);
  }

  return <div className="jalali-picker-wrap">
    <label className="store-field"><span>{label}</span><button type="button" className="jalali-picker-trigger" aria-haspopup="dialog" aria-expanded={open} onClick={() => setOpen((previous) => !previous)}><span>{labelValue}</span><ChevronDown size={17} /></button></label>
    {open && <div className="jalali-calendar" role="dialog" aria-label="انتخاب تاریخ شمسی">
      <div className="jalali-calendar-header"><button type="button" aria-label="ماه قبل" onClick={() => moveMonth(-1)}><ChevronRight size={18} /></button><strong>{months[month - 1]} {fa.format(year)}</strong><button type="button" aria-label="ماه بعد" disabled={year === current.jy && month === current.jm} onClick={() => moveMonth(1)}><ChevronLeft size={18} /></button></div>
      <div className="jalali-calendar-grid jalali-weekdays">{weekdays.map((day) => <span key={day}>{day}</span>)}</div>
      <div className="jalali-calendar-grid">
        {Array.from({ length: firstWeekday }, (_, index) => <span className="jalali-calendar-blank" key={`blank-${index}`} />)}
        {days.map((day) => {
          const isSelected = selected?.jy === year && selected.jm === month && selected.jd === day;
          const isFuture = year === current.jy && (month > current.jm || (month === current.jm && day > current.jd));
          return <button type="button" key={day} disabled={isFuture} aria-pressed={isSelected} className={isSelected ? "selected" : ""} onClick={() => { onChange(isoDate(year, month, day)); setOpen(false); }}>{fa.format(day)}</button>;
        })}
      </div>
      <div className="jalali-calendar-footer"><button type="button" onClick={() => { onChange(""); setOpen(false); }}>پاک کردن</button><button type="button" onClick={() => setOpen(false)}>بستن</button></div>
    </div>}
  </div>;
}
