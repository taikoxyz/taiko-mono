module.exports = {
    plugins: [require("daisyui")],
    theme: {
        extend: {}
    },
    daisyui: {
        styled: true,
        themes: true,
        base: true,
        utils: true,
        logs: true,
        rtl: false,
        prefix: "",
        darkTheme: "dark",
        themes: [
            {
              dark: {
                ...require("daisyui/colors/themes")["[data-theme=black]"],
                "primary": "#242424",
                "secondary": "#181818",
                "accent": "#FC0FC0",
                "neutral": "#272626",
                "base-100": "#0f0f0f",
                "info": "#373737",
                "success": "#008000",
                "warning": "#FFFF00",
                "error": "#FF0000",
              },
            },
          ],
    }
};
