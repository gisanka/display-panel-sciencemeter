# Display Panel Sciencemeter

[![Release](https://github.com/gisanka/display-panel-sciencemeter/actions/workflows/release.yml/badge.svg?branch=main)](https://github.com/gisanka/display-panel-sciencemeter/actions/workflows/release.yml)

Display Panel Sciencemeter creates a blueprint book of display-panel science meters for all science packs in your current game.

Run one command and the mod generates a blueprint book containing one blueprint per science pack. Each blueprint contains a single display panel that shows the matching science pack icon, a colored 0-100% progress bar, and aligned percent text.

## Features

- Generates a blueprint book in-game from the science packs of the current game.
- Creates one display-panel blueprint per science pack.
- Uses translated science pack names for blueprint labels when available.
- Colors each progress bar with a curated preset color and user-defined opacity.
- Works with modded games because generation happens at runtime in the current save.

## Usage

Open the console and run:

```text
/sciencemeter-book [[width=]width] [[opacity=]opacity]
```

The generated blueprint book is placed in your cursor. If your cursor cannot be cleared, empty your cursor and run the command again.

You can optionally pass a bar width and opacity:

```text
/sciencemeter-book 5 75
/sciencemeter-book 5 0.75
/sciencemeter-book 5 75%
```

The default width is 5.
The default opacity is 75%.

## Signal Input

Each generated display panel expects a circuit network signal for its science pack:

- Signal name: the science pack shown by that blueprint
- Signal value: a percentage from `0` to `100`

For example, the automation science blueprint reads the `automation-science-pack` signal and displays the corresponding percentage.

If you connect a panel directly to a container or a belt with "read (all belts)", circuit logic is needed to scale the value to `0-100` before feeding the signal into the display panel.

## Modpack Compatibility

Science packs are discovered at runtime from the `lab_inputs` of all loaded lab prototypes. Duplicate items are removed, and the book is sorted by Factorio item prototype order so science packs appear in a predictable order.

This should work with many modpacks because generation happens inside the current save. It does not guarantee that every modpack has curated colors or that every unusual lab setup will look ideal.

## After Generation

The mod does not add custom entities or items. The generated blueprints use Factorio Display Panels and item signals, so you can keep using the generated blueprint book without keeping this mod enabled, as long as the target save still has the referenced Display Panel and science pack items.

## Limitations

- The mod creates blueprint books only when you run the command; it does not place panels automatically.
- Each blueprint contains one Display Panel.
- The input signal must already be scaled to percent.
- The Display Panel has 100 message entries. The generated scale covers `0-100`, with `49` skipped.
- Curated color presets are incomplete for some modpacks

## Development

Releases are automated with semantic-release and semantic-release-factorio. The changelog and generated release version is written to `info.json` during release.
