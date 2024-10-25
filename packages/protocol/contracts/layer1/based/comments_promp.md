Improve docs by:

1. making sure the comments are using NatSpecs correctly
2. Make sure each external and public functions are documented, prefer @notice over @dev
3. For libraries, make sure all internal functions are also documented, prefer @notice over @dev
4. For private functions, if there is an existing NatSpecs comments, make sure parameters are aso documented.
5. Correct typos but do not make uncessary rewording to minimize the changes.
6. Use /// style comments, not /\*\* \*\*/ style.
7. If NatSpecs doc string is broken into multiple lines, reformat it to one line.
