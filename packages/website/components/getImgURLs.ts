import jsdom from "jsdom";
const { JSDOM } = jsdom;
global.DOMParser = new JSDOM().window.DOMParser;
const parser = new DOMParser();

export const getImgURLs = new Promise<Array<String>>((resolve, reject) => {
    async function getImgURLs() {
        fetch("https://cors-anywhere.herokuapp.com/https://mirror.xyz/labs.taiko.eth/")
            .then(function (response) {
                return response.text();
            })
            .then(function (html) {
                // Convert the HTML string into a document object
                const doc = parser.parseFromString(html, "text/html");
                // var imgTags = doc.getElementsByTagName("img");
                var cardImgs: NodeListOf<HTMLImageElement> = doc.querySelectorAll(`img[alt="Card Header"]`);

                var cardImgsURL: string[] = [];
                // Filter out the correct link an extract the url out of them
                cardImgs.forEach((img) => {
                    const cardImgURL = (decodeURIComponent(img.src));
                    if (!cardImgURL.includes("data")) {
                        const urlStartIndex = cardImgURL.indexOf("url=") + 4;
                        cardImgsURL.push(cardImgURL.substring(urlStartIndex));
                    }
                });
                resolve(cardImgsURL)
            })
            .catch();
}
    getImgURLs()
})