---
title: ERB templates & layouts
summary: How pages get wrapped in a layout.
---
Each page names a layout in its front matter, or gets `default`. The layout is an ERB template that sees `site`, `page`, `posts` and `content`.

Text in a template is escaped with `h`, so a title like <Spinel & Ruby> is safe.
