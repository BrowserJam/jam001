#include <complex.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "raylib.h"

#define MAX_TEXT_ROW 1024
#define MAX_TEXT_COLS 1024
#define MAX_PARAMS_COUNT 32
#define MAX_PARAMS_LENGTH 1024
#define MAX_TOKENS 1024
#define MAX_STACK_SIZE 20
#define MAX_INPUT_LENGTH 1024

typedef unsigned int uint;
typedef enum FontTypes{
    FONTS_REGULAR = 0,
    FONTS_BOLD,
    FONTS_ITALIC,
    FONTS_BOLD_ITALIC,
    FONTS_TEST,
    FONTS_MAX,
} FontTypes;


typedef enum {
    STATE_FindStartOfData,
    STATE_FindStartOfToken,
    STATE_ParseData,
    STATE_EndOfData
} ParserState;

typedef enum {
    TAG_nil,
    TAG_html,
    TAG_head,
    TAG_header,
    TAG_meta,
    TAG_body,
    TAG_title,
    TAG_nextid,
    TAG_h,
    TAG_a,
    TAG_p,
    TAG_dl,
    TAG_dt,
    TAG_dd,

} TagState;

typedef struct {
    char name[32];
    char params[MAX_PARAMS_COUNT][MAX_PARAMS_LENGTH];
    char values[MAX_PARAMS_COUNT][MAX_PARAMS_LENGTH];
    size_t params_count;
    TagState type;
    bool is_end;
} Tag;

/* function prototypes */

void ResetTokens();
void DrawSearchBar(Rectangle screen, bool does_file_exist);
Tag SetupEmptyTag();
void DrawPagePath(Rectangle screen);
Rectangle GetScreenRenderWindow(Camera2D camera);
void AsignTagType(Tag *t);
bool CompareNames(char str1[], char str2[], char str3[]);
bool IsTag(int i);
void PrintMousePosition();
void LoadAllFonts();
void UnloadAllFonts();
void RemoveTagsLine(char line[]);
void AddCharToCurrentToken(char c);
void StoreCurrentToken();
void ParseText(FILE *input_file);
void ParseTokenToTag(Tag *tag, int idx);
void PrintLine(char line[], Vector2 pos, uint font_size, uint font_spacing);

/* constants */
Font fonts[FONTS_MAX];
const double mouse_scroll_speed = 20;
char input[MAX_INPUT_LENGTH+1] = {0};
uint input_length = 0;


char current_token[4096];
size_t current_token_length;
char tokens[MAX_TOKENS][4096];
size_t tokens_count = 0;

ParserState parser_state = STATE_FindStartOfData;



int main(int argc, char *argv[])
{
    strcpy(input, "../input.html");
    FILE *f = fopen(input, "r");
    ParseText(f);
    input_length = strlen(input);
    InitWindow(960, 640, "Ooga booga browser ;)");
    TagState current_tag = TAG_nil;
    Camera2D camera = {
        .target = (Vector2){GetScreenWidth()*0.5f, GetScreenHeight()*0.5f},
        .offset = (Vector2){GetScreenWidth()*0.5f, GetScreenHeight()*0.5f},
        .zoom = 1.0f,
        .rotation = 0,
    };
    LoadAllFonts();
    GenTextureMipmaps(&fonts[FONTS_REGULAR].texture);
    SetTextureFilter(fonts[FONTS_REGULAR].texture, TEXTURE_FILTER_BILINEAR);
    Rectangle screen = GetScreenRenderWindow(camera);

    bool mouse_on_text = false;
    bool does_file_exist = true;
    char page_title[1024] = {0};

    while(!WindowShouldClose()){
        BeginDrawing(); 
        BeginMode2D(camera);
        ClearBackground(WHITE);
        if(camera.target.y>=screen.y+0.5f*screen.height+20 && GetMouseWheelMove()>0){
            camera.target.y -= GetMouseWheelMove()*mouse_scroll_speed;
        }
        else if(GetMouseWheelMove()<=0)
            camera.target.y -= GetMouseWheelMove()*mouse_scroll_speed;
        uint font_size = 24;
        uint font_spacing = 0;

        if(IsKeyPressed(KEY_F)){
            ToggleFullscreen();
        }
        DrawSearchBar(screen, does_file_exist);
        Rectangle input_background = {.x = screen.x+10, screen.y+40, .width=GetScreenWidth()-20, .height=40};
        Rectangle title_background = {.x = screen.x+10, screen.y+100, .width = MeasureText(page_title, font_size)+10, .height = 40};
        DrawRectangleRec(title_background, LIGHTGRAY);
        DrawTextEx(fonts[FONTS_REGULAR], page_title, (Vector2){screen.x+15, screen.y+105}, font_size, font_spacing, BLACK);
        if(CheckCollisionPointRec(GetMousePosition(), input_background))
            mouse_on_text = true;
        else 
            mouse_on_text = false;

        if(mouse_on_text){
            int key = GetCharPressed();
            while(key > 0){
                if((key >= 32) && (key <= 126) && input_length < MAX_INPUT_LENGTH){
                    input[input_length] = (char)key;
                    input[input_length+1] = '\0';
                    input_length++;
                }
                key = GetCharPressed();
            }
            if(IsKeyPressed(KEY_BACKSPACE)){
                    if(input_length>0){
                        input[input_length-1] = 0;
                        input_length--;
                    }
                    else{
                        input[0]='\0';
                        input_length = 0;
                    }
            }
            if(IsKeyPressed(KEY_ENTER)){
                FILE *file;
                if((file = fopen(input, "r"))){
                    //File exists
                    does_file_exist = true;
                    ParseText(file);
                }
                else{
                    does_file_exist = false;
                }
            }
            SetMouseCursor(MOUSE_CURSOR_IBEAM);
        }
        else SetMouseCursor(MOUSE_CURSOR_DEFAULT);
        DrawPagePath(screen);

        const Vector2 default_pos = {screen.x+20, screen.y+150};
        const Color default_font_color = BLACK;
        const uint default_font_size = 20;
        const uint default_font_spacing = 0;
        Font default_font = fonts[FONTS_REGULAR];

        
        font_size = default_font_size;
        font_spacing = default_font_spacing;
        Font current_font = default_font;
        Vector2 position = default_pos;
        Color font_color = BLACK;   
        uint space_len=MeasureTextEx(fonts[FONTS_REGULAR], " ", 
                                        font_size, font_spacing).x;
        char line[8192]={0};
        bool new_line_before = false;
        bool new_line_after = false;
        TagState tag_s[5] = {0};
        for(size_t i=0;i<tokens_count;i++){
            if(IsTag(i)){
                Tag t = SetupEmptyTag();
                ParseTokenToTag(&t, i);
                AsignTagType(&t);
                for(int i=0;i<5;i++){
                    if(tag_s[i] == t.type && t.is_end){
                        for(int j=i;j<4;j++){
                            tag_s[j] = tag_s[j+1];
                        }
                        tag_s[4] = TAG_nil;
                        break;
                    }
                    else if(tag_s[i] == TAG_nil && !t.is_end){
                        tag_s[i] = t.type;
                        switch(t.type){
                            case TAG_html:
                            case TAG_meta:
                            case TAG_body:
                            case TAG_head:
                            case TAG_header:
                                tag_s[i] = TAG_nil;
                                break;
                            case TAG_dl:
                                new_line_before = true;
                                break;
                            case TAG_h:
                                current_font = fonts[FONTS_BOLD];
                                font_size += 20;
                                new_line_before = true;
                                new_line_after = true;
                                break;
                            case TAG_dd:
                                position.x=default_pos.x+30;
                                position.y+=30;
                                break;
                            case TAG_p:
                            case TAG_dt:
                                font_size = default_font_size;
                                new_line_before = true;
                                break;
                            default:
                                font_size = default_font_size;
                                break;
                        }
                        break;
                    }
                }
            }
            for(int j=0;j<5;j++){
                    if(tag_s[0]==0){
                        font_color = BLACK;
                        new_line_before = false;
                        current_font = fonts[FONTS_REGULAR];
                        font_size = default_font_size;
                        break;
                    }
                    if(tag_s[j]==0){
                        break;
                    };
                    switch(tag_s[j]){
                       case TAG_nil:
                           new_line_before = false;
                           font_color = BLACK;
                           font_size = default_font_size;
                           break;
                       case TAG_a:
                           font_color = BLUE;
                           new_line_before = false;
                           break;
                       case TAG_p:
                           font_color = BLACK;
                           break;
                       case TAG_h:
                           font_color = BLACK;
                           break;
                       default:
                           font_color = BLACK;
                           break;
                }
            }
            if(new_line_before){
                position.y+=30;
                position.x = default_pos.x;
                new_line_before = false;
            }
            if(!IsTag(i)){
                if(tag_s[0] != TAG_title){
                    strcpy(line, tokens[i]);
                    strcat(line, " ");
                    DrawTextEx(current_font, tokens[i], position, font_size, font_spacing, font_color);
                    position.x+=MeasureTextEx(current_font, line, font_size, font_spacing).x;
                    if(new_line_after){
                        if(tag_s[0]==TAG_h){
                            position.y+=50;
                        }
                        else 
                            position.y+=30;
                        position.x = default_pos.x;
                        new_line_after = false;
                    }
                }
                else 
                    strcpy(page_title, tokens[i]);
            }

        }
        EndMode2D();
        EndDrawing();
    }

    CloseWindow();
    //UnloadAllFonts();
}
void DrawSearchBar(Rectangle screen, bool does_file_exist){
    Rectangle input_background = {.x = screen.x+10, screen.y+40, .width=screen.width-20, .height=40};
    if(does_file_exist)
        DrawRectangleRec(input_background, LIGHTGRAY);
    else 
        DrawRectangleRec(input_background, RED);

}
void ResetTokens(){
    strcpy(current_token, "");
    current_token_length = 0;
    for(int i=0;i<tokens_count;i++){
        strcpy(tokens[i], "");
    }
    tokens_count = 0;
}
void DrawPagePath(Rectangle screen){
    uint font_size = 24;
    uint font_spacing = 0;
    DrawTextEx(fonts[FONTS_REGULAR], input, 
            (Vector2){screen.x+15, screen.y+50}, font_size, font_spacing, 
            BLACK);

}
Rectangle GetScreenRenderWindow(Camera2D camera){
    Rectangle rect;
    rect.width= GetScreenWidth()/camera.zoom*(1.0);
    rect.height = GetScreenHeight()/camera.zoom*(1.0);
    rect.x = camera.target.x - 0.5f*rect.width;
    rect.y = camera.target.y -0.5f*rect.height;
    return rect;
}
void PrintLine(char line[], Vector2 pos, uint font_size, uint font_spacing){
    DrawTextEx(fonts[FONTS_REGULAR], 
            line, pos, font_size, font_spacing, BLACK);
}
bool IsTag(int i){
    if(tokens[i][0]=='<')
        return true;
    else return false;
}
Tag SetupEmptyTag(){
    return (Tag){
        .name = {0},
        .params = {{0}},
        .values = {{0}},
        .params_count = 0,
        .type = TAG_nil,
        .is_end = 0,
    };
}
bool CompareNames(char str1[], char str2[], char str3[]){
    if(strcmp(str1, str2)==0 || strcmp(str1, str3) == 0){
        return true;
    }
    else return false;
}
void AsignTagType(Tag *t){
    if(t->name[0]=='/')
        t->is_end = true;
    if(CompareNames(t->name, "html", "/html"))
        t->type = TAG_html;
    else if(CompareNames(t->name, "head", "/head"))
        t->type = TAG_head;
    else if(CompareNames(t->name, "meta", "/meta"))
        t->type = TAG_meta;
    else if(CompareNames(t->name, "body", "/body"))
        t->type = TAG_body;
    else if(CompareNames(t->name, "header", "/header"))
        t->type = TAG_header;
    else if(CompareNames(t->name, "nextid", "/nextid"))
        t->type = TAG_nextid;
    else if(CompareNames(t->name, "title", "/title"))
        t->type = TAG_title;
    else if(CompareNames(t->name, "h1", "/h1"))
        t->type = TAG_h;
    else if(CompareNames(t->name, "h2", "/h2"))
        t->type = TAG_h;
    else if(CompareNames(t->name, "h3", "/h3"))
        t->type = TAG_h;
    else if(CompareNames(t->name, "h4", "/h4"))
        t->type = TAG_h;
    else if(CompareNames(t->name, "h5", "/h5"))
        t->type = TAG_h;
    else if(CompareNames(t->name, "h6", "/h6"))
        t->type = TAG_h;
    else if(CompareNames(t->name, "p", "/p"))
        t->type = TAG_p;
    else if(CompareNames(t->name, "a", "/a"))
        t->type = TAG_a;
    else if(CompareNames(t->name, "dl", "/dl"))
        t->type = TAG_dl;
    else if(CompareNames(t->name, "dd", "/dd"))
        t->type = TAG_dd;
    else if(CompareNames(t->name, "dt", "/dt"))
        t->type = TAG_dt;
}
void ParseTag(int i){
    if(IsTag(i)){
        Tag t = SetupEmptyTag();
        ParseTokenToTag(&t, i);


    }
}
void PrintMousePosition(){
    printf("MOUSE POSITION: %d, %d\n", GetMouseX(), GetMouseY());
}
void LoadAllFonts(){
    fonts[FONTS_REGULAR] = LoadFontEx("../fonts/RobotoMonoNerdFont-Regular.ttf", 92, NULL, 0);
    fonts[FONTS_BOLD] = LoadFontEx("../fonts/RobotoMonoNerdFont-Bold.ttf", 128, NULL, 0);
    fonts[FONTS_ITALIC] = LoadFontEx("../fonts/RobotoMonoNerdFont-Italic.ttf", 128, NULL, 0);
    fonts[FONTS_BOLD_ITALIC] = LoadFontEx("../fonts/RobotoMonoNerdFont-BoldItalic.ttf.ttf", 128, NULL, 0);
    fonts[FONTS_TEST] = LoadFontEx("../fonts/alagard.ttf", 32, NULL, 0);
}
void UnloadAllFonts(){
    for(int i=0;i<FONTS_MAX;i++)
        UnloadFont(fonts[i]);
}
void RemoveTagsLine(char line[]){
    if(strcmp(line, "\n")=='\n')
        return;
    char arr[1024] = "";
    size_t len = 0, count = 0;
    bool inside_tag = false;
    len = strlen(line);
    for(size_t i=0;i<len;i++){
        if(line[i]=='<'){
            inside_tag = true;
        }
        if(!inside_tag)
            arr[count++] = line[i];
        if(line[i]=='\n')
            continue;
        if(line[i]=='>'){
            if(line[i+1]=='\n')
                line[i+1]='\0';
            inside_tag = false;
        }
    }
    strncpy(line, arr, len+1);
}

void AddCharToCurrentToken(char c){
    if(current_token_length < sizeof(current_token))
        current_token[current_token_length++] = c;
}
void StoreCurrentToken(){
    AddCharToCurrentToken('\0');
    strncpy(tokens[tokens_count++], current_token, 4095);
    for(size_t i=0;i<4096; i++)
        current_token[i] = 0;
    current_token_length = 0;
}
void ParseTokenToTag(Tag *tag, int idx){
    typedef enum {
        TYPE_TAG_NAME,
        TYPE_TAG_PARAMETER,
        TYPE_TAG_VALUE,
    } TagParseState;
    TagParseState tps;
    bool is_end = 0;
    bool search_for_next = 0;
    if(tokens[idx][0]!='<') return;
    size_t tok_len = strnlen(tokens[idx], 4095);
    tps = TYPE_TAG_NAME;
    for(int i=1;i<tok_len;i++){
        char c = tokens[idx][i];
        switch(tps){
            case TYPE_TAG_NAME:
                if(c=='<') break;
                if(c=='>') return;
                if(c==' '){
                    tps = TYPE_TAG_PARAMETER;
                    break;
                }
                if(c=='/')
                    is_end = true;
                if(c>=32 && c<=126){
                    size_t len = strlen(tag->name);
                    if(len>=0 && len<32){
                        tag->name[len] = c;
                    }
                    break;
                }
            case TYPE_TAG_PARAMETER:
                search_for_next = false;
                if(c==' ') break;
                if(c=='=') break;
                if(c=='>') return;
                if(c=='"'){
                    tps = TYPE_TAG_VALUE;
                    break;
                }
                if(c>=32 && c<=126){
                    size_t len = strlen(tag->params[tag->params_count]);
                    if(len<MAX_PARAMS_LENGTH){
                        tag->params[tag->params_count][len] = c;
                    }
                    break;
                }
                break;

            case TYPE_TAG_VALUE:
                if(c=='"'){
                    search_for_next = true;
                    tag->params_count++;
                    break;
                }
                if(c==' ' && search_for_next){
                    tps = TYPE_TAG_PARAMETER;
                    break;
                }
                if(c=='>' && search_for_next){
                    return;
                }
                if(c>=32 && c<=126){
                size_t len = strlen(tag->values[tag->params_count]);
                    if(len<MAX_PARAMS_LENGTH){
                        tag->values[tag->params_count][len] = c;
                    }
                    break;
                }
                break;


        }
    }
}

void ParseText(FILE *input_file){
    ResetTokens();
    while(parser_state != STATE_EndOfData) {
        char c = fgetc(input_file);
        if(c == -1){
            StoreCurrentToken();
            return;
        }
        switch(parser_state){
            case STATE_FindStartOfData:
                if(c == '\n' || c == '\r') break;
            case STATE_FindStartOfToken:
                // Skip whitespace
                if(c==' ' || c == '\t' || c=='\n' || c=='\r') break;
                if((c >= 33 && c <= 126)){
                    parser_state = STATE_ParseData;
                    AddCharToCurrentToken(c);
                    break;
                }
                printf("Unexpected ASCII code!: %c, in state:%d\n", c, STATE_FindStartOfToken);
                break;
            case STATE_ParseData:
                if(c=='\n' || c=='\r' || c==10){
                    AddCharToCurrentToken(' ');
                    break;
                }
                if(c=='>'){
                    AddCharToCurrentToken(c);
                    StoreCurrentToken();
                    parser_state = STATE_FindStartOfToken;
                    break;
                }
                if(c=='<'){
                    StoreCurrentToken();
                    AddCharToCurrentToken(c);
                    parser_state = STATE_FindStartOfToken;
                    break;
                }
                if(c>=32 && c<=126){
                    AddCharToCurrentToken(c);
                    break;
                }
                printf("Unexpected ASCII code!: %d, in state:%d\n", c, STATE_ParseData);
                break;
            case STATE_EndOfData:
                return;
        }
    }
}
