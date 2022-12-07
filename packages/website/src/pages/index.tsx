import React from "react";
import Layout from "@theme/Layout";
import BlogSection from "../components/BlogSection";
import JoinUs from "../components/JoinUs";
import Features from "../components/Features";
import Hero from "../components/Hero";
import Head from "@docusaurus/Head";

export default function Home(): JSX.Element {
  return (
    <Layout
      title="Taiko"
      description="Type 1 ZK-EVM -- A fully decentralized, Ethereum-equivalent ZK-Rollup."
    >
      <Head>
        <meta
          property="og:image"
          content="@site/static/img/Taiko_Logo_Fluo.svg"
        />
      </Head>
      <Hero />
      <Features />
      <BlogSection />
      <JoinUs />
    </Layout>
  );
}
