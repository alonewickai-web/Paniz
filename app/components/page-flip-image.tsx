import type { ReactEventHandler } from "react";
import { StoreImage } from "./store-image";

export type FlipImage = { src: string; alt: string };

type PageFlipImageProps = {
  src: string;
  alt: string;
  outgoing?: FlipImage | null;
  direction: "next" | "previous";
  sizes: string;
  priority?: boolean;
  className?: string;
  onError?: ReactEventHandler<HTMLImageElement>;
};

export function PageFlipImage({ src, alt, outgoing, direction, sizes, priority, className, onError }: PageFlipImageProps) {
  return <>
    <StoreImage src={src} alt={alt} fill priority={priority} sizes={sizes} className={className} onError={onError} />
    {outgoing && <div
      key={`${outgoing.src}-${direction}`}
      className={`page-flip-leaf page-flip-leaf-${direction}`}
      aria-hidden="true"
    >
      <StoreImage src={outgoing.src} alt="" fill sizes={sizes} className={className} />
    </div>}
  </>;
}
