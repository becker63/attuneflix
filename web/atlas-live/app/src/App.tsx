import * as stylex from "@stylexjs/stylex";

import { documentTitle } from "./title.ts";

const styles = stylex.create({
  root: {
    fontFamily: "system-ui, sans-serif",
    padding: 16,
  },
});

export function App() {
  return (
    <main {...stylex.props(styles.root)}>
      <h1>{documentTitle(undefined)}</h1>
    </main>
  );
}
