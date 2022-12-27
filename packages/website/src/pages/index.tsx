import React from "react";
import Layout from "@theme/Layout";
import BlogSection from "../components/BlogSection";
import JoinUs from "../components/JoinUs";
import Features from "../components/Features";
import Hero from "../components/Hero";
import Head from "@docusaurus/Head";
import AddEthereumChainButton from "../components/AddEthereumChainButton";

export default function Home(): JSX.Element {
  return (
    <Layout description="A Type 1 ZK-EVM -- Fully decentralized, Ethereum-equivalent ZK-Rollup.">
      <Head>
        <meta
          property="og:image"
          content="https://taiko.xyz/img/Taiko_Logo_Fluo.png"
        />
      </Head>
      <Hero />
      <Features />
      <BlogSection />
      <JoinUs />
    </Layout>
  );
}
