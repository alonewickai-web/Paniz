"use client";

import { useCallback, useEffect, useState, type FormEvent } from "react";
import { Star } from "lucide-react";
import { apiBaseUrl } from "../lib/catalog";
import { CustomerApiError, customerApi } from "../lib/customer-api";

type ProductReview = { id: string; rating: number; title: string | null; body: string | null; createdAt: string; verifiedPurchase: boolean };
type ReviewFeed = { total: number; averageRating: number | null; reviews: ProductReview[] };
type ReviewOrder = { orderItemId: string; productName: string; color: string; size: string; orderNumber: string; purchasedAt: string };

const persianDate = new Intl.DateTimeFormat("fa-IR", { dateStyle: "medium" });

export function ProductReviews({ productId, slug }: { productId: string; slug: string }) {
  const [feed, setFeed] = useState<ReviewFeed | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [formOpen, setFormOpen] = useState(false);
  const [orders, setOrders] = useState<ReviewOrder[]>([]);
  const [selectedOrder, setSelectedOrder] = useState("");
  const [rating, setRating] = useState(0);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [loadingOrders, setLoadingOrders] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState("");

  const loadReviews = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const response = await fetch(`${apiBaseUrl()}/products/${encodeURIComponent(slug)}/reviews`, { cache: "no-store" });
      if (!response.ok) throw new Error("بارگذاری نظرهای این محصول انجام نشد.");
      const payload = await response.json() as { data?: ReviewFeed };
      setFeed(payload.data ?? { total: 0, averageRating: null, reviews: [] });
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "بارگذاری نظرها انجام نشد.");
    } finally {
      setLoading(false);
    }
  }, [slug]);

  useEffect(() => { void loadReviews(); }, [loadReviews]);

  async function openReviewForm() {
    setNotice("");
    setRating(0);
    setFormOpen(true);
    if (orders.length || loadingOrders) return;
    setLoadingOrders(true);
    try {
      const available = await customerApi<ReviewOrder[]>(`/customer/products/${encodeURIComponent(productId)}/review-orders`);
      setOrders(available);
      setSelectedOrder(available[0]?.orderItemId ?? "");
      if (!available.length) setNotice("ثبت نظر پس از پرداخت و تحویل سفارش فعال می‌شود.");
    } catch (reason) {
      if (reason instanceof CustomerApiError && reason.status === 401) {
        window.location.assign(`/account?next=${encodeURIComponent(window.location.pathname)}`);
        return;
      }
      setNotice(reason instanceof Error ? reason.message : "دریافت خریدهای شما انجام نشد.");
    } finally {
      setLoadingOrders(false);
    }
  }

  async function submitReview(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (rating < 1) {
      setNotice("برای ثبت نظر، ابتدا امتیازتان را با انتخاب ستاره مشخص کنید.");
      return;
    }
    if (!selectedOrder || submitting) return;
    setSubmitting(true);
    setNotice("");
    try {
      await customerApi(`/customer/products/${encodeURIComponent(productId)}/reviews`, {
        method: "POST",
        body: JSON.stringify({ orderItemId: selectedOrder, rating, title: title.trim() || undefined, body: body.trim() || undefined }),
      });
      setFormOpen(false);
      setTitle("");
      setBody("");
      setOrders((items) => items.filter((item) => item.orderItemId !== selectedOrder));
      setSelectedOrder("");
      setNotice("نظر شما ثبت شد و پس از تأیید ادمین نمایش داده می‌شود.");
      await loadReviews();
    } catch (reason) {
      if (reason instanceof CustomerApiError && reason.status === 401) {
        window.location.assign(`/account?next=${encodeURIComponent(window.location.pathname)}`);
        return;
      }
      setNotice(reason instanceof Error ? reason.message : "ثبت نظر انجام نشد.");
    } finally {
      setSubmitting(false);
    }
  }

  return <div className="product-reviews">
    <div className="product-reviews-summary">
      <div><strong>{feed?.averageRating ? new Intl.NumberFormat("fa-IR", { maximumFractionDigits: 1 }).format(feed.averageRating) : "—"}</strong><span className="product-review-stars" aria-label="امتیاز میانگین">{[1, 2, 3, 4, 5].map((item) => <Star key={item} size={15} fill={feed?.averageRating && item <= Math.round(feed.averageRating) ? "currentColor" : "none"} />)}</span><small>{new Intl.NumberFormat("fa-IR").format(feed?.total ?? 0)} نظر تأییدشده</small></div>
      <button className="button-primary" type="button" onClick={() => void openReviewForm()}>ثبت نظر</button>
    </div>

    {notice && <p className="product-review-notice" role="status">{notice}</p>}
    {formOpen && <form className="product-review-form" onSubmit={submitReview}>
      {loadingOrders ? <p>در حال بررسی خریدهای شما…</p> : orders.length > 0 ? <>
        <label>خرید این محصول
          <select value={selectedOrder} onChange={(event) => setSelectedOrder(event.target.value)} required>
            {orders.map((order) => <option key={order.orderItemId} value={order.orderItemId}>{order.color} / {order.size} · سفارش {order.orderNumber}</option>)}
          </select>
        </label>
        <fieldset className="product-review-rating"><legend>امتیاز شما {rating > 0 && `· ${new Intl.NumberFormat("fa-IR").format(rating)} از ۵`}</legend><div>{[1, 2, 3, 4, 5].map((item) => <button key={item} type="button" className={item <= rating ? "selected" : ""} aria-label={`${item} از ۵`} aria-pressed={rating === item} onClick={() => setRating(item)}><Star size={23} fill={item <= rating ? "currentColor" : "none"} /></button>)}</div></fieldset>
        <label>عنوان (اختیاری)<input maxLength={160} value={title} onChange={(event) => setTitle(event.target.value)} /></label>
        <label>نظر شما (اختیاری)<textarea maxLength={2000} rows={4} value={body} onChange={(event) => setBody(event.target.value)} /></label>
        <div className="product-review-form-actions"><button type="button" className="button-quiet" onClick={() => setFormOpen(false)}>انصراف</button><button className="button-primary" type="submit" disabled={!selectedOrder || rating < 1 || submitting}>{submitting ? "در حال ثبت…" : "ثبت برای بررسی"}</button></div>
      </> : <button type="button" className="button-quiet" onClick={() => setFormOpen(false)}>بستن</button>}
    </form>}

    {loading ? <p className="product-review-muted">در حال دریافت نظرها…</p> : error ? <p className="product-review-muted" role="status">{error} <button type="button" onClick={() => void loadReviews()}>تلاش دوباره</button></p> : feed?.reviews.length ? <div className="product-review-list">
      {feed.reviews.map((review) => <article className="product-review-card" key={review.id}>
        <div className="product-review-card-heading"><strong>{review.title || "نظر خریدار"}</strong><time dateTime={review.createdAt}>{persianDate.format(new Date(review.createdAt))}</time></div>
        <span className="product-review-stars" aria-label={`امتیاز ${review.rating} از ۵`}>{[1, 2, 3, 4, 5].map((item) => <Star key={item} size={14} fill={item <= review.rating ? "currentColor" : "none"} />)}</span>
        {review.body && <p>{review.body}</p>}
        {review.verifiedPurchase && <small>خریدار تأییدشده</small>}
      </article>)}
    </div> : <p className="product-review-muted">هنوز نظری برای این محصول ثبت نشده است.</p>}
  </div>;
}
