# CLI Bookmarks
- **Fedora 42** з dnf 5
- **GNOME** + **Wayland**
- **Python 3** (встановлено за замовчуванням)
- **fzf** - fuzzy finder


## Використання

**Ctrl+Space** - відкрити меню закладок

### Робочий процес:
1. Натискаєш **Ctrl+Space**
2. Вибираєш категорію (стрілки/миша)
3. Вибираєш команду
4. Команда вставляється в рядок терміналу
5. Редагуєш параметри і натискаєш Enter


## Редагування закладок

Файл: `~/.local/share/cli-bookmarks/bookmarks`

```
##CATEGORY_NAME
command {{parameter}} # Description
another command       # Another description

##ANOTHER_CATEGORY
...
```

### Placeholder(s)
- `{{parameter}}` - позначає місце для редагування
- Курсор автоматично позиціонується на першому placeholder
- Комментарі автоматично видаляються при вставці


```

## Після встановлення

Файли встановлюються в:
- `~/.local/share/cli-bookmarks/` - програма і закладки
- `~/.local/bin/cli-bookmarks` - symlink для запуску


## Додавання команд
Просто відредагуйте `~/.local/share/cli-bookmarks/bookmarks`:
```
##MY_CATEGORY
my-command {{param}}  # My description
```

## Видалення

```bash
rm -rf ~/.local/share/cli-bookmarks
rm -f ~/.local/bin/cli-bookmarks
# Видалити рядки з ~/.bashrc вручну
```
