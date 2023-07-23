import Link from "next/link";

export function StyledLink(props) {
  const { href, text } = props;
  return (
    <Link
      href={href}
      className="nx-text-primary-600 nx-underline nx-decoration-from-font [text-underline-position:from-font]"
      target="_blank"
      rel="noopener noreferrer"
    >
      {text}
    </Link>
  );
}
