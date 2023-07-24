function EcosystemCard({ icon, name, link, description }) {
  return (
    <a
      href={link}
      target="_blank"
      rel="noopener noreferrer"
      className="rounded-xl shadow-md bg-white dark:bg-neutral-800 p-6 flex flex-col justify-start items-start transition-colors duration-200 hover:shadow-xl dark:hover:bg-neutral-700"
    >
      <div className="w-16 h-16 flex justify-center items-center mb-4">
        <img
          src={icon}
          alt={`${name}-logo`}
          className="max-w-full max-h-full object-contain"
        />
      </div>
      <h2 className="text-2xl text-black dark:text-white font-bold mb-2">
        {name}
      </h2>
      <p className="text-neutral-500 dark:text-neutral-300 mb-4">{link}</p>
      <p className="text-neutral-700 dark:text-neutral-100">{description}</p>
    </a>
  );
}

export { EcosystemCard };
