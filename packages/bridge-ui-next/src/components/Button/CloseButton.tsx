"use client";

import { Icon } from "@/components/Icon";

export interface CloseButtonProps {
  onClick: () => void;
}

export default function CloseButton({ onClick }: CloseButtonProps) {
  return (
    <button className="absolute right-6 z-50" onClick={onClick}>
      <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
    </button>
  );
}
