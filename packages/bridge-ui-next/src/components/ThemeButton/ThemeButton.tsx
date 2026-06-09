"use client";

import { useEffect, useMemo } from "react";

import { Icon } from "@/components/Icon";
import { web3modal } from "@/libs/connect";
import { Theme, useThemeStore } from "@/stores/useThemeStore";

export interface ThemeButtonProps {
  mobile?: boolean;
}

export default function ThemeButton({ mobile = false }: ThemeButtonProps) {
  const theme = useThemeStore((state) => state.theme);
  const setTheme = useThemeStore((state) => state.setTheme);

  const isDarkTheme = useMemo(() => theme === Theme.DARK, [theme]);

  const darkFill = useMemo(
    () => (isDarkTheme ? "fill-grey-600" : "fill-grey-0"),
    [isDarkTheme],
  );
  const lightFill = useMemo(
    () => (isDarkTheme ? "fill-grey-0" : "fill-grey-600"),
    [isDarkTheme],
  );

  function switchTheme() {
    const currentTheme = theme;
    const newTheme = currentTheme === Theme.DARK ? Theme.LIGHT : Theme.DARK;
    document.documentElement.setAttribute("data-theme", newTheme);
    localStorage.setItem("theme", newTheme);
    web3modal.setThemeMode(newTheme);
    // setTheme updates the store and applies the data-theme attribute (parity with `$theme = newTheme`).
    setTheme(newTheme);
  }

  useEffect(() => {
    const current = localStorage.getItem("theme");
    if (!current || (current !== Theme.DARK && current !== Theme.LIGHT)) {
      setTheme(Theme.DARK);
    } else {
      setTheme(current as Theme);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (mobile) {
    return (
      <label className="cursor-pointer grid place-items-center">
        <input
          type="checkbox"
          checked={isDarkTheme}
          onChange={switchTheme}
          className="
                    toggle toggle-md toggle-grey-600 row-start-1 col-start-1 col-span-2 theme-controller
                      bg-grey-0 border-grey-600 [--tglbg:theme(colors.grey.600)] checked:bg-grey-0 checked:border-blue-800 checked:[--tglbg:theme(colors.grey.600)] hover:bg-grey-0

                    "
        />
        <Icon
          type="moon"
          className="col-start-2 row-start-1"
          size={16}
          fillClass={darkFill}
        />
        <Icon
          type="sun"
          className="col-start-1 row-start-1"
          size={16}
          fillClass={lightFill}
        />
      </label>
    );
  }

  return (
    <label className="swap swap-rotate">
      <input
        type="checkbox"
        className="border-none"
        checked={isDarkTheme}
        onChange={switchTheme}
      />
      <Icon type="sun" className="fill-primary-icon swap-on " size={25} />
      <Icon type="moon" className="fill-primary-icon swap-off" size={25} />
    </label>
  );
}
