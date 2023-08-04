export function FAQBox({ title, children }) {
    return (
        <details
            open
            className="last-of-type:mb-0 rounded-lg bg-neutral-50 dark:bg-neutral-800 p-2 mt-4"
        >
            <summary>
                <strong className="text-lg">{title}</strong>
            </summary>
            <div className="nx-p-2">{children}</div>
        </details>
    )
}
