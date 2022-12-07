import React from "react";
import Layout from "@theme/Layout";
import BlogSection from "../components/BlogSection";
import JoinUs from "../components/JoinUs";
import Features from "../components/Features";
import Hero from "../components/Hero";

export default function Home(): JSX.Element {
  return (
    <Layout>
      <Hero />
      <Features />
      <BlogSection />
      <JoinUs />
    </Layout>
  );
}
