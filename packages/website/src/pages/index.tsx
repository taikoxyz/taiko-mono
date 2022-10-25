import React from "react";
import clsx from "clsx";
import Link from "@docusaurus/Link";
import useDocusaurusContext from "@docusaurus/useDocusaurusContext";
import Layout from "@theme/Layout";
import HomepageFeatures from "@site/src/components/HomepageFeatures";
import { useColorMode } from "@docusaurus/theme-common";

import styles from "./index.module.css";

function HomepageHeader() {
  const { colorMode } = useColorMode();
  const { siteConfig } = useDocusaurusContext();

  return (
    <header className={clsx("hero", styles.heroBanner)}>
      <div className="container">
        {colorMode === "dark" ? (
          <img
            src="./img/Taiko_Logo-Original_Pink_White.svg"
            alt="Taiko Logo"
            width="200px"
          />
        ) : (
          <img
            src="./img/Taiko_Logo-Original_Pink_Black.svg"
            alt="Taiko Logo"
            width="200px"
          />
        )}
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            href="./taiko-whitepaper.pdf"
          >
            Read the whitepaper
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home(): JSX.Element {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout description={`${siteConfig.tagline}`}>
      <HomepageHeader />
      <main>
        <HomepageFeatures />
      </main>
    </Layout>
  );
}
