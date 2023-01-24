import Image from "next/image";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";

function ThemedImage() {
  const { resolvedTheme } = useTheme();
  const [src, setSrc] = useState(null);

  useEffect(() => {
    setSrc(
      resolvedTheme === "dark"
        ? "/images/logotype-white.png"
        : "/images/logotype-black.png"
    );
  }, [resolvedTheme]);

  return src ? (
    <Image
      src={src}
      width={100}
      height={100}
      alt="logo"
      style={{ width: "100%", height: "auto" }}
    />
  ) : null;
}

export default ThemedImage;
