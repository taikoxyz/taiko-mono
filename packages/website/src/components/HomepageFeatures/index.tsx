import React from "react";
import clsx from "clsx";
import styles from "./styles.module.css";

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<"svg">>;
  description: JSX.Element;
};

const FeatureList: FeatureItem[] = [
  {
    title: "Accessible",
    Svg: require("@site/static/img/undraw_connected_world_wuay.svg").default,
    description: (
      <>
        Anyone who wants to build on or use Taiko can do so.
        This is because the transaction fees are cheap and throughput
        is high; the developer experience is robust and Ethereum dapp migration
        is seamless. You can’t have freedom without access.
      </>
    ),
  },
  {
    title: "Inclusive",
    Svg: require("@site/static/img/undraw_having_fun_re_vj4h.svg").default,
    description: (
      <>
        Taiko is censorship-resistant and cannot exclude groups or individuals.
        The rollup is decentralized - relying on Ethereum for data availability
        and security; and permissionless - allowing any network participant to opt-in. 
        We are only interested in building credibly neutral, fair systems.
      </>
    ),
  },
  {
    title: "Open",
    Svg: require("@site/static/img/undraw_collaboration_re_vyau.svg").default,
    description: (
      <>
        Taiko is fully open-source and community-centric. We build on the
        shoulders of giants, and cherish contributing back into Ethereum’s
        technical progress and community. We value community contributions into
        the project, harnessing the best minds and ideas in the space.
      </>
    ),
  },
];

function Feature({ title, Svg, description }: FeatureItem) {
  return (
    <div className={clsx("col col--4")}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <h3>{title}</h3>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): JSX.Element {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
