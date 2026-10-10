import Image from "next/image";

type StoreImageProps = {
  src: string;
  alt: string;
  fill?: boolean;
  width?: number;
  height?: number;
  sizes?: string;
  priority?: boolean;
  className?: string;
};

export function StoreImage({ src, alt, fill, width, height, sizes, priority, className }: StoreImageProps) {
  if (/^https:\/\//i.test(src)) {
    return <img
      src={src}
      alt={alt}
      width={fill ? undefined : width}
      height={fill ? undefined : height}
      loading={priority ? "eager" : "lazy"}
      decoding="async"
      className={className}
      style={fill ? { position: "absolute", inset: 0, width: "100%", height: "100%" } : undefined}
    />;
  }

  return <Image src={src} alt={alt} fill={fill} width={fill ? undefined : width} height={fill ? undefined : height} sizes={sizes} priority={priority} className={className} />;
}
