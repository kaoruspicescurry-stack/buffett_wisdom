import re
import json

def main():
    with open("buffett_wisdom_ゆっくり台本.md", "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    script_data = []
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Check if section header
        if line.startswith("## パート"):
            part_title = line.replace("#", "").strip()
            script_data.append({
                "speaker": "演出・ナレーション",
                "dialogue": f"=== {part_title} ===",
                "effect": ""
            })
            continue
            
        # Check if speaker line
        match = re.match(r'^\*\*([^*]+)\*\*「([^」]+)」', line)
        if match:
            speaker = match.group(1).strip()
            dialogue = match.group(2).strip()
            script_data.append({
                "speaker": speaker,
                "dialogue": dialogue,
                "effect": ""
            })
            continue
            
        # General narrative or other text
        if line.startswith("**【登場人物】**") or line.startswith("- **"):
            continue
            
        # Other text
        script_data.append({
            "speaker": "演出・ナレーション",
            "dialogue": line,
            "effect": ""
        })

    # Generate Google Apps Script code
    gas_template = """/**
 * Google Apps Script for color-coding and exporting the Warren Buffett Yukkuri script.
 * Sheet Name: "シート9"
 */
function createBuffettScript() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const targetSheetName = "シート9";
  
  // Create or clear the target sheet
  let sheet = ss.getSheetByName(targetSheetName);
  if (sheet) {
    sheet.clear();
  } else {
    sheet = ss.insertSheet(targetSheetName);
  }

  // Script Data Array
  const SCRIPT_DATA = @SCRIPT_DATA@;

  // Build values array
  const header = [["話者", "セリフ", "演出・ナレーション"]];
  const body = SCRIPT_DATA.map(item => [item.speaker, item.dialogue, item.effect]);
  const allData = header.concat(body);

  const numRows = allData.length;
  const numCols = 3;
  const range = sheet.getRange(1, 1, numRows, numCols);
  range.setValues(allData);

  // Character Color Definition (Curated Palette for Yukkuri Reimu & Marisa)
  const COLOR_MAP = {
    "魔理沙": { bg: "#E8F0FE", text: "#1A73E8" },             // 魔理沙 (青): インテリ魔理沙カラー
    "霊夢": { bg: "#FFEBEB", text: "#D93025" },               // 霊夢 (赤): 巫女の赤カラー
    "魔理沙・霊夢": { bg: "#FEF7E0", text: "#B06000" },       // 2人掛け合い (黄色)
    "演出・ナレーション": { bg: "#F1F3F4", text: "#5F6368" }    // 演出・ナレーション: グレー
  };

  const backgrounds = [];
  const fontColors = [];
  const fontStyles = [];

  // Header Styling (Row 1)
  backgrounds.push(["#E8EAED", "#E8EAED", "#E8EAED"]);
  fontColors.push(["#202124", "#202124", "#202124"]);
  fontStyles.push(["normal", "normal", "normal"]);

  // Set style for each row
  SCRIPT_DATA.forEach(item => {
    let style;
    if (item.speaker === "演出・ナレーション") {
      style = COLOR_MAP["演出・ナレーション"];
    } else {
      style = COLOR_MAP[item.speaker] || { bg: "#FFFFFF", text: "#000000" };
    }

    backgrounds.push([style.bg, style.bg, style.bg]);
    fontColors.push([style.text, style.text, style.text]);
    fontStyles.push([
      "normal",
      "normal",
      item.effect !== "" ? "italic" : "normal"
    ]);
  });

  // Apply Styles in Batch for speed
  range.setBackgrounds(backgrounds);
  range.setFontColors(fontColors);
  range.setFontStyles(fontStyles);

  // Bold Headers
  sheet.getRange("A1:C1").setFontWeights([["bold", "bold", "bold"]]);

  // Adjust Column Widths
  sheet.autoResizeColumns(1, 3);
  sheet.setColumnWidth(2, 550); // Dialogue column width
  sheet.setColumnWidth(3, 300); // Action/Narrative column width

  // Center vertically & wrap text
  range.setVerticalAlignment("middle").setWrap(true);

  ss.toast("シート「" + targetSheetName + "」に台本を整理・色分けして出力しました！", "完了", 5);
}
"""
    
    script_data_str = json.dumps(script_data, ensure_ascii=False, indent=2)
    full_gas = gas_template.replace("@SCRIPT_DATA@", script_data_str)
    
    with open("buffett_wisdom_gas.gs", "w", encoding="utf-8") as f:
        f.write(full_gas)
        
    print("✅ Generated buffett_wisdom_gas.gs successfully!")

if __name__ == "__main__":
    main()
