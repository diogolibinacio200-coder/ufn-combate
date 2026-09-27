# Créditos, procedência e licenças

## Autoria e contato

**Criado e desenvolvido por Diogo Liberalesso Inácio.**

**Feito por Diogo Liberalesso Inácio. Para contato ou feedback, fale no Instagram [@diogok_i](https://www.instagram.com/diogok_i/) ou pelo e-mail [diogolib.inacio200@gmail.com](mailto:diogolib.inacio200@gmail.com)!**

UFN Combate — Edição Campus, versão 0.2.0, 2026. Desenvolvimento assistido por IA, a partir da direção e dos materiais fornecidos pelo autor.

## Base técnica

A implementação parte do projeto [Nexus Kombat](https://github.com/diogolibinacio200-coder/nexus-kombat), da mesma conta do autor, com adaptação e ampliação do combate, interface, elenco, progressão, áudio e modo de kart.

## Materiais do projeto

- **Personagens:** sprites fornecidos pelo autor em setembro de 2026. O processamento remove fundos, recorta poses, organiza atlas e prepara retratos. [Correspondência de arquivos e personagens](docs/REFERENCIAS.md).
- **Animações:** sequências de poses dos atlas, combinadas com interpolação, deslocamentos e efeitos em Godot. Não representam dezenas de novos desenhos independentes por animação.
- **Arenas:** oito imagens produzidas com a ferramenta de geração de imagens integrada. Quatro utilizam referências locais pesquisadas e quatro são composições temáticas. As fotografias originais não integram as arenas distribuídas; os respectivos autores e links constam em [REFERENCIAS.md](docs/REFERENCIAS.md).
- **Urso de Fernando:** atlas de oito poses gerado para o jogo e usado com efeitos e posicionamento próprios.
- **Kart e efeitos:** geometria, veículos, itens e efeitos construídos no código do projeto.
- **Música e efeitos sonoros:** síntese produzida para a base do projeto e reproduzível por `tools/generate_audio.py`.
- **Narrador:** síntese em português do Brasil com a voz **Microsoft Maria Desktop**, instalada no computador de desenvolvimento. Gerador: `tools/generate_announcer_pt.ps1`. Não é gravação de um ator.
- **Identidade UFN:** nome, marca e logotipo institucional pertencem aos respectivos titulares. O arquivo do logo foi obtido no portal da UFN. A presença da identidade universitária no jogo não declara aprovação ou patrocínio institucional.

Este documento registra a procedência dos materiais; não concede uma licença geral de reutilização das imagens fornecidas, personagens, marca institucional ou voz. Nenhuma licença única para todo o código e toda a arte foi definida nesta entrega. As licenças dos componentes de terceiros abaixo continuam aplicáveis aos respectivos componentes.

## Godot Engine

**Godot Engine 4.7.2 — licença MIT.**

Copyright (c) 2014–present Godot Engine contributors. Copyright (c) 2007–2014 Juan Linietsky, Ariel Manzur.

O texto incluído está em [docs/GODOT-LICENSE.txt](docs/GODOT-LICENSE.txt). Informações e avisos dos componentes da engine estão na [página oficial de licenças da Godot](https://godotengine.org/license/) e no editor em **Ajuda → Sobre → Licenças de terceiros**.

## Fonte Rajdhani

Copyright (c) 2014, Indian Type Foundry.

**SIL Open Font License 1.1.** Texto integral em [assets/fonts/OFL.txt](assets/fonts/OFL.txt).

## Distribuição

O pacote Windows desta versão contém **UFNCombate.exe** e **UFNCombate.pck**, que devem permanecer juntos. O executável é uma cópia byte a byte do binário oficial **Godot 4.7.2**, apenas renomeado, preservando sua assinatura Authenticode válida. Os dados de UFN Combate ficam no PCK separado. A assinatura cobre a engine oficial; não constitui assinatura do conteúdo, da autoria ou da distribuição do jogo por Diogo Liberalesso Inácio. Os avisos da engine e da fonte devem acompanhar o pacote.

As referências a outros jogos descrevem inspiração de gênero e estrutura; o projeto não inclui assets extraídos de Mortal Kombat ou Street Fighter.
