import { useEffect, useState } from "react";

import Image from "next/image";
import { useTheme } from "next-themes";

function ThemedImage() {
  const { resolvedTheme } = useTheme();
  const [src, setSrc] = useState(null);

  useEffect(() => {
    setSrc(
      resolvedTheme === "dark"
        ? "/images/logotype-white.svg"
        : "/images/logotype-black.svg"
    );
  }, [resolvedTheme]);

  return src ? (
    <Image
      src={src}
      width={100}
      height={100}
      alt="logo"
      style={{ width: "128px", height: "auto" }}
    />
  ) : null;
}

export { ThemedImage };
