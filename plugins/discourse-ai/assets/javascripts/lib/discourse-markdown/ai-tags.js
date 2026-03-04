export function setup(helper) {
  helper.allowList(["details[class=ai-quote]", "details[class=ai-thinking]"]);
  helper.allowList([
    "div[class=ai-artifact]",
    "div[data-ai-artifact-id]",
    "div[data-ai-artifact-version]",
    "div[data-ai-artifact-autorun]",
    "div[data-ai-artifact-height]",
    "div[data-ai-artifact-width]",
  ]);
  helper.allowList([
    "div[class=data-explorer-chart]",
    "div[data-chart-config]",
  ]);

  helper.registerPlugin((md) => {
    md.block.bbcode.ruler.push("data-explorer-chart", {
      tag: "data-explorer-chart",
      replace(state, tagInfo, content) {
        const openToken = state.push("div_open", "div", 1);
        openToken.attrs = [
          ["class", "data-explorer-chart"],
          ["data-chart-config", content.trim()],
        ];
        state.push("div_close", "div", -1);
        return true;
      },
    });
  });
}
