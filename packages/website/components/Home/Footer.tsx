export function Footer() {
  return (
    <footer className="bg-neutral-100 dark:bg-neutral-900">
      <div className="mx-auto max-w-[90rem] pl-3">
        <div className="grid grid-cols-2 pl-[max(env(safe-area-inset-left),1.5rem)] pr-[max(env(safe-area-inset-right),1.5rem)] py-8 md:grid-cols-3">
          <div>
            <h2 className="font-grotesk mb-6 text-lg text-neutral-500 dark:text-neutral-300 pt-3">
              About
            </h2>
            <ul className="text-neutral-500 dark:text-neutral-400">
              <li className="mb-4">
                <a
                  href="https://mirror.xyz/labs.taiko.eth"
                  className="hover:underline"
                  target={"_blank"}
                >
                  Blog
                </a>
              </li>
              <li className="mb-4">
                <a
                  href="https://www.notion.so/taikoxyz/Taiko-Jobs-828fd7232d2c4150a11e10c8baa910a2"
                  className="hover:underline"
                  target={"_blank"}
                >
                  Careers
                </a>
              </li>
              <li className="mb-4">
                <a
                  href="https://github.com/taikoxyz/taiko-mono/tree/main/packages/branding/"
                  className="hover:underline"
                  target={"_blank"}
                >
                  Brand kit
                </a>
              </li>
            </ul>
          </div>
          <div>
            <h2 className="font-grotesk mb-6 text-lg text-neutral-500 dark:text-neutral-300 pt-3">
              Developers
            </h2>
            <ul className="text-neutral-500 dark:text-neutral-400">
              <li className="mb-4">
                <a href="/docs" className="hover:underline">
                  Get started
                </a>
              </li>
              <li className="mb-4">
                <a
                  href="https://github.com/taikoxyz"
                  className="hover:underline"
                  target={"_blank"}
                >
                  GitHub
                </a>
              </li>
              <li className="mb-4">
                <a
                  href="/docs/resources/integration-guide"
                  className="hover:underline"
                >
                  Integration manual
                </a>
              </li>
            </ul>
          </div>
          <div>
            <h2 className="font-grotesk mb-6 text-lg text-neutral-500 dark:text-neutral-300 pt-3">
              Follow us
            </h2>
            <ul className="text-neutral-500 dark:text-neutral-400">
              <li className="mb-4">
                <a
                  href="https://discord.gg/taikoxyz"
                  className="hover:underline"
                  target={"_blank"}
                >
                  Discord
                </a>
              </li>
              <li className="mb-4">
                <a
                  href="https://twitter.com/taikoxyz"
                  className="hover:underline"
                  target={"_blank"}
                >
                  Twitter
                </a>
              </li>
              <li className="mb-4">
                <a
                  href="https://www.youtube.com/@taikoxyz"
                  className="hover:underline"
                  target={"_blank"}
                >
                  YouTube
                </a>
              </li>
            </ul>
          </div>
        </div>
        <div className="font-groteskmedium text-md text-center text-neutral-500 dark:text-neutral-300 bg-neutral-100 dark:bg-neutral-900 px-4 py-6">
          © {new Date().getFullYear()} Taiko Labs
        </div>
      </div>
    </footer>
  );
}
