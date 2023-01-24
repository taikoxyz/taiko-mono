import React, { useEffect, useState } from "react";
import { getImgURLs } from "./getImgURLs";
import { getOriginalDigests } from "./getOriginalDigests";
import { getPosts } from "./getPosts";

const authors = [
  {
    address: "0x381636D0E4eD0fa6aCF07D8fd821909Fb63c0d10",
    profileImg: "https://mirror-media.imgix.net/publication-images/aWkXh0tO8n-j2jSU996_5.jpeg?h=400&w=400",
    name: "finestone",
  },
  {
    address: "0x2b1F13149C7F89622BBfB46Ae1e3ECc573Bb9331",
    profileImg: "https://mirror-media.imgix.net/publication-images/XadIvjIRb2wI3Aglq3r01.png?h=720&w=762",
    name: "d1onys1us",
  },
  {
    address: "0x5b796c4b197b6dfd413f177059c27963eb80af0f",
    profileImg: "https://mirror-media.imgix.net/publication-images/R0_XDunSEvn58KGo31NtD.png?h=1001&w=1001",
    name: "Taiko Labs",
  }
];

// Add the correct Original-Content-Digest, this is neccesarry for making the link to the mirror page
function addOriginalDigests(objects, digests) {
  for (let i = 0; i < objects.length; i++) {
    for (let j = 0; j < digests.length; j++) {
      if (objects[i].digest === digests[j].node.tags[3].value) {
        objects[i]["OriginalDigest"] = digests[j].node.tags[4].value;
      }
    }
  }
  return objects;
}

// Add the authors picture and name based on the contriboter address
function addAuthorDetails(objects, authors) {
  for (let i = 0; i < objects.length; i++) {
    for (let j = 0; j < authors.length; j++) {
      if (objects[i].authorship.contributor === authors[j].address) {
        objects[i].authorship["name"] = authors[j].name;
        objects[i].authorship["profileImg"] = authors[j].profileImg;
      }
    }
  }
  return objects;
}

function addImgURLs(objects, imgURLs) {
  for (let i = 0; i < objects.length; i++) {
    objects[i]["ImgURL"] = imgURLs[i];
  }
  return objects;
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

export default function BlogSection(): JSX.Element {
  const [posts, setPosts] = useState([]);

  useEffect(() => {
    // This is getting the 'Orginal-Content-Digest' aswell asa the 'Content-Digest', this is nesscary for making the link to the mirror page
    getOriginalDigests.then((result) => {
      const originalDigestsResult = result;

      getImgURLs.then((result) => {
        const ImgURLs = result;

        getPosts.then((result) => {
          // add the OriginalDigest to the post object
          result = addOriginalDigests(result, originalDigestsResult);

          // add author details to the post object
          result = addAuthorDetails(result, authors);

          // add the ImgURL to the post object
          result = addImgURLs(result, ImgURLs);

          setPosts(result);
        });
      });

      // Getting the information of the post via the arweave GraphQL and SDK
    });
  }, []);

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
          {posts.map((post) => (
            <div
              key={post.content.title}
              className="flex flex-col overflow-hidden rounded-lg shadow-lg"
            >
              <div className="flex-shrink-0">
                <a
                  href={
                    "https://mirror.xyz/labs.taiko.eth/" + post.OriginalDigest
                  }
                  target="_blank"
                >
                  <img
                    className="h-54 w-full object-cover"
                    src={post.ImgURL}
                    alt=""
                  />
                </a>
              </div>
              <div className="flex flex-1 flex-col justify-between bg-white p-6 dark:bg-neutral-800">
                <div className="flex-1">
                  <a
                    href={
                      "https://mirror.xyz/labs.taiko.eth/" + post.OriginalDigest
                    }
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
                  <div className="flex-shrink-0">
                    <a>
                      <span className="sr-only">{post.authorship.name}</span>
                      <img
                        className="h-10 w-10 rounded-full"
                        src={post.authorship.profileImg}
                        alt=""
                      />
                    </a>
                  </div>
                  <div className="ml-3">
                    <div className="text-sm font-medium text-neutral-900">
                      <a>{post.authorship.name}</a>
                    </div>
                    <div className="flex space-x-1 text-sm text-neutral-500 dark:text-neutral-400">
                      <time dateTime={getDateTime(post.content.timestamp)}>
                        {getDate(post.content.timestamp)}
                      </time>
                      <span aria-hidden="true">&middot;</span>
                      <span>{getReadingTime(post.content.body) + " min"}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
