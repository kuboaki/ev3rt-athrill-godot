#include "util.h"

// 演習用のユーティリティ
const int8_t line_height = 20;

// 初期処理用
void init_f(const char *str) {
  // フォントの設定と0行目の表示
  ev3_lcd_set_font(EV3_FONT_MEDIUM);
  ev3_lcd_draw_string(str, 0, 0);
}

/**
 * 引数の行を消去
 * @param line 20ドットごとの行番号（1から5）
 */
void clear_f(const int32_t line) {
  ev3_lcd_fill_rect(0, line * line_height,
                    EV3_LCD_WIDTH, line_height,
                    EV3_LCD_WHITE);
}

/**
 * 行単位で引数の文字列を表示
 * @param str 表示する文字列
 * @param line 20ドットごとの行番号（1から5）
 */
void msg_f(const char *str, int32_t line) {
  clear_f(line);
  ev3_lcd_draw_string(str, 0, line * line_height);
}

/**
 * 行単位で引数の数値を表示
 * @param n 表示する数値
 * @param line 20ドットごとの行番号（1から5）
 */
void num_f(const int n, int32_t line) {
  static char buf[25] = {0};
  snprintf(buf, sizeof(buf), "%d", n);
  clear_f(line);
  ev3_lcd_draw_string(buf, 0, line * line_height);
}
