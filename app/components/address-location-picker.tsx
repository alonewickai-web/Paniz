"use client";

import { useEffect, useMemo, useRef } from "react";
import { MapContainer, TileLayer, useMap, useMapEvents } from "react-leaflet";
import { LocateFixed, MapPinned } from "lucide-react";

type Props = {
  latitude: number | null;
  longitude: number | null;
  onChange: (latitude: number, longitude: number) => void;
  fallbackLatitude?: number;
  fallbackLongitude?: number;
};

function MapClick({ onChange }: Pick<Props, "onChange">) {
  const userMoved = useRef(false);
  const map = useMapEvents({
    click: ({ latlng }) => { map.panTo(latlng); onChange(latlng.lat, latlng.lng); },
    dragstart: () => { userMoved.current = true; },
    moveend: () => {
      if (!userMoved.current) return;
      userMoved.current = false;
      const point = map.getCenter(); onChange(point.lat, point.lng);
    },
  });
  return null;
}

function CenterUpdater({ latitude, longitude }: { latitude: number; longitude: number }) {
  const map = useMap();
  useEffect(() => { map.setView([latitude, longitude], map.getZoom(), { animate: true }); }, [latitude, longitude, map]);
  return null;
}

export function AddressLocationPicker({ latitude, longitude, onChange, fallbackLatitude = 35.6892, fallbackLongitude = 51.389 }: Props) {
  const center = useMemo<[number, number]>(() => [latitude ?? fallbackLatitude, longitude ?? fallbackLongitude], [fallbackLatitude, fallbackLongitude, latitude, longitude]);
  return <div className="address-location-picker">
    <div className="address-map-frame">
      <MapContainer center={center} zoom={latitude !== null && longitude !== null ? 16 : 12} scrollWheelZoom={false} className="address-map">
        <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
        <MapClick onChange={onChange} />
        <CenterUpdater latitude={center[0]} longitude={center[1]} />
      </MapContainer>
      <span className="address-map-center-pin" aria-hidden="true"><MapPinned size={30} fill="var(--rose)" /></span>
      <button type="button" className="address-map-locate" aria-label="استفاده از موقعیت فعلی" title="موقعیت فعلی" onClick={() => {
        if (!navigator.geolocation) return;
        navigator.geolocation.getCurrentPosition(({ coords }) => onChange(coords.latitude, coords.longitude), () => undefined, { enableHighAccuracy: true, timeout: 10000 });
      }}><LocateFixed size={18} /></button>
    </div>
    <div className="address-map-caption">
      <span>{latitude === null || longitude === null ? "روی نقشه ضربه بزن و نشان را روی محل دقیق بگذار" : "نشان قرمز را بکش یا روی نقطهٔ دقیق ضربه بزن"}</span>
      {latitude !== null && longitude !== null && <bdi dir="ltr">{latitude.toFixed(6)}، {longitude.toFixed(6)}</bdi>}
    </div>
  </div>;
}
