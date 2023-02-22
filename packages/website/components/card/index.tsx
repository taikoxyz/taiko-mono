type Props = {
  title: string;
  description: string;
  href: string;
  imageSrc: string;
};

export function Card(props: Props): JSX.Element {
  return (
    <div className="max-w-sm bg-white border border-neutral-200 rounded-lg shadow dark:bg-neutral-800 dark:border-neutral-700">
      <a href={props.href} target="_blank" rel="noopener noreferrer">
        <img
          className="rounded-t-lg w-full h-40 sm:h-64 lg:h-36 xl:h-48 object-cover object-top"
          src={props.imageSrc}
          alt=""
        />
      </a>
      <div className="p-5">
        <a href={props.href} target="_blank" rel="noopener noreferrer">
          <h5 className="mb-2 text-2xl font-bold tracking-tight text-neutral-900 dark:text-white">
            {props.title}
          </h5>
        </a>
        <p className="mb-3 font-normal text-neutral-700 dark:text-neutral-400">
          {props.description}
        </p>
        <div className="inline-flex rounded-md shadow">
          <a
            href={props.href}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center rounded-md border border-transparent bg-[#e30ead] px-3 py-2 text-base font-semibold text-white dark:text-neutral-100 hover:bg-[#bd0b90] hover:no-underline hover:text-white"
          >
            View
            <svg
              aria-hidden="true"
              className="w-4 h-4 ml-2 -mr-1"
              fill="currentColor"
              viewBox="0 0 20 20"
              xmlns="http://www.w3.org/2000/svg"
            >
              <path
                fill-rule="evenodd"
                d="M10.293 3.293a1 1 0 011.414 0l6 6a1 1 0 010 1.414l-6 6a1 1 0 01-1.414-1.414L14.586 11H3a1 1 0 110-2h11.586l-4.293-4.293a1 1 0 010-1.414z"
                clip-rule="evenodd"
              ></path>
            </svg>
          </a>
        </div>
      </div>
    </div>
  );
}
