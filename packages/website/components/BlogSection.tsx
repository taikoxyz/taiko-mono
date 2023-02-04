import React, { useEffect, useState } from "react";
import { getPosts } from "./getPosts";

interface Content {
  body: string;
  timestamp: number;
  title: string;
}

interface Authorship {
  contributor: string;
  signingKey: {
    crv: string;
    ext: boolean;
    key_ops: string[];
    kty: string;
    x: string;
    y: string;
  };
  signature: string;
  signingKeySignature: string;
  signingKeyMessage: string;
  algorithm: {
    name: string;
    hash: string;
  };
}

interface Wnft {
  chainId: number;
  description: string;
  fee: number;
  fundingRecipient: string;
  imageURI: string;
  mediaAssetId: number;
  name: string;
  nonce: number;
  owner: string;
  price: number;
  proxyAddress: string;
  renderer: string;
  supply: number;
  symbol: string;
}

interface Post {
  OriginalDigest : string;
  content: Content;
  authorship: Authorship;
  digest: string;
  version: string;
  wnft: Wnft;
}


function getReadingTime(text) {
  const wordsPerMinute = 200;
  const wordCount = text.split(" ").length;
  const readingTime = Math.round(wordCount / wordsPerMinute);
  return readingTime;
}

function getDate(timestamp: string): string {
  let date = new Date(Number(timestamp) * 1000);
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function getDateTime(timestamp: string): string {
  let date = new Date(parseInt(timestamp) * 1000);
  return `${date.getFullYear()}-${(date.getMonth() + 1)
    .toString()
    .padStart(2, "0")}-${date.getDate().toString().padStart(2, "0")}`;
}

function checkIfPostAreSet(posts) {
  if (posts.length > 0) {
    return posts.map((post : Post) => (
      <div
        key={post.content.title}
        className="flex flex-col overflow-hidden rounded-lg shadow-lg"
      >
        <div className="flex-shrink-0">
          <a
            href={"https://mirror.xyz/labs.taiko.eth/" + post.OriginalDigest}
            target="_blank"
          >
            <img
              className="h-54 w-full object-cover crop-image"
              src={`https://ipfs.io/ipfs/${post.wnft.imageURI}`}
              alt=""
            />
          </a>
        </div>
        <div className="flex flex-1 flex-col justify-between bg-white p-6 dark:bg-neutral-800">
          <div className="flex-1">
            <a
              href={"https://mirror.xyz/labs.taiko.eth/" + post.OriginalDigest}
              target="_blank"
              className="mt-2 block"
            >
              <div className="text-xl font-semibold text-neutral-900 dark:text-neutral-200">
                {post.content.title}
              </div>
              <div className="mt-3 text-base text-neutral-500 dark:text-neutral-300">
                {post.wnft.description}
              </div>
            </a>
          </div>
          <div className="mt-6 flex items-center">
            <div className="ml-3">
              <div className="flex space-x-1 text-sm text-neutral-500 dark:text-neutral-400">
                <time dateTime={getDateTime(`${post.content.timestamp}`)}>
                  {getDate(`${post.content.timestamp}`)}
                </time>
                <span aria-hidden="true">&middot;</span>
                <span>{getReadingTime(post.content.body) + " min read"}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    ));
  } else {
    const amountOfPostsToDisplay = 3;
    return [...Array(amountOfPostsToDisplay)].map((v, i) => (
      <div
        key={i}
        className="flex flex-col overflow-hidden rounded-lg shadow-lg"
      >
        <div className="load-wraper">
          <div className="activity"></div>
        </div>
      </div>
    ));
  }
}

export default function BlogSection(): JSX.Element {
  const [posts, setPosts] = useState<Object[]>([]);

  useEffect(() => {
    getPosts.then((result : Post[]) => {
      // only use the last three
      result = result.sort((a, b) => b.content.timestamp - a.content.timestamp);
      result = result.slice(0, 3);

      setPosts(result);
    });
    // getting the information of the post via the arweave GraphQL and SDK
  });

  return (
    <div className="relative bg-neutral-50 px-4 pt-16 pb-20 sm:px-6 lg:px-8 lg:pt-24 lg:pb-28 dark:bg-neutral-800">
      <div className="absolute inset-0">
        <div className="h-1/3 bg-white sm:h-2/3 dark:bg-[#1B1B1D]" />
      </div>
      <div className="relative mx-auto max-w-7xl">
        <div className="text-center">
          <h2 className="font-oxanium text-3xl font-bold tracking-tight text-neutral-900 sm:text-4xl dark:text-neutral-100">
            Latest blog posts
          </h2>
          <div className="mx-auto mt-3 max-w-2xl text-xl text-neutral-500 sm:mt-4 dark:text-neutral-300">
            Check out the full blog at{" "}
            <a href="https://mirror.xyz/labs.taiko.eth" target="_blank">
              mirror.xyz
            </a>
          </div>
        </div>

        <div className="mx-auto mt-12 grid max-w-lg gap-5 lg:max-w-none lg:grid-cols-3">
          {checkIfPostAreSet(posts)}
        </div>
      </div>
    </div>
  );
}
