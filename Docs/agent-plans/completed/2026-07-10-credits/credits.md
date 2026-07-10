# Licenses & Credits Window

## Goal

Create a window in SwiftUI to display licenses and credits inside a macOS app.

The window should display:

- A sidebar with one row per item, ordered alphabetically:
    - The project's name
    - The project's author (below, secondary)
    - A pill with the project's license name (right)
- A detail view showing the selected project:
    - The project's name (title)
    - A pill with the project's license name (right)
    - A separator
    - The project's author
    - The project's description
    - A link to the project's website
    - A scrollable text view with the project's license

A consumer app should be able to configure and display the window, passing all the necessary information, including license files (as text).
