# Installing Webfonts

Follow these simple Steps.

## 1.

Put `clash-grotesk/` Folder into a Folder called `fonts/`.

## 2.

Put `clash-grotesk.css` into your `css/` Folder.

## 3. (Optional)

You may adapt the `url('path')` in `clash-grotesk.css` depends on your Website Filesystem.

## 4.

Import `clash-grotesk.css` at the top of you main Stylesheet.

```
@import url('clash-grotesk.css');
```

## 5.

You are now ready to use the following Rules in your CSS to specify each Font Style:

```
font-family: ClashGrotesk-Extralight;
font-family: ClashGrotesk-Light;
font-family: ClashGrotesk-Regular;
font-family: ClashGrotesk-Medium;
font-family: ClashGrotesk-Semibold;
font-family: ClashGrotesk-Bold;
font-family: ClashGrotesk-Variable;

```

## 6. (Optional)

Use `font-variation-settings` rule to controlaxes of variable fonts:
wght 700.0

Available axes:
'wght' (range from 200.0 to 700.0
