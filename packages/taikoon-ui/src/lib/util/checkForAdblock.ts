// Function to check if the bait element has been hidden or removed by an adblocker
export const checkForAdblocker = async (urlToTest: string): Promise<boolean> => {
  return new Promise((resolve) => {
    const bait = document.createElement('script');
    bait.src = urlToTest;
    bait.type = 'text/javascript';
    bait.onerror = () => {
      // Script failed to load, likely due to an adblocker
      resolve(true);
    };
    bait.onload = () => {
      // Script loaded successfully, likely no adblocker
      resolve(false);
    };
    document.body.appendChild(bait);
    // Ensure the bait element is removed from the DOM afterwards
    bait.remove();
  });
};
