// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import { themes as prismThemes } from "prism-react-renderer";

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: "Async Dataflow",
  tagline:
    "The Async DataFlow component aims to deliver asynchronous responses in real time to client applications, thus enabling end-to-end asynchronois flows without losing the ability to respond in real time or eventually, send data to client applications as a result of asynchronous operations and oriented to messages / commands / events on the platform.",
  favicon: "img/logo.svg",

  // Set the production url of your site here
  url: "https://bancolombia.github.io",
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: "/async-dataflow/",

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: "Bancolombia", // Usually your GitHub org/user name.
  projectName: "async-dataflow", // Usually your repo name.

  onBrokenLinks: "throw",

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: "en",
    locales: ["en"],
  },

  presets: [
    [
      "classic",
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: "./sidebars.js",
          docItemComponent: "@theme/ApiItem",
          editUrl:
            "https://github.com/bancolombia/async-dataflow/tree/master/docs/",
        },
        theme: {
          customCss: "./src/css/custom.css",
        },
      }),
    ],
  ],
  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: "warn",
    },
  },
  plugins: [
    [
      'docusaurus-plugin-openapi-docs',
      {
        id: "api", // plugin id
        docsPluginId: "classic", // configured for preset-classic
        config: {
          channelsender: {
            specPath: "../channel-sender/swagger.yaml",
            outputDir: "docs/channel-sender/api",
            maskCredentials: false, // Disable credential masking in code snippets
            sidebarOptions: {
              groupPathsBy: "tag",
            },
          },
        }
      },
    ]
  ],
  themes: ["docusaurus-theme-openapi-docs", "@docusaurus/theme-mermaid"],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      // Replace with your project's social card
      image: "img/docusaurus-social-card.jpg",
      navbar: {
        title: "Async Dataflow",
        logo: {
          alt: "Async Dataflow Logo",
          src: "img/logo.svg",
        },
        items: [
          {
            type: "docSidebar",
            sidebarId: "tutorialSidebar",
            position: "left",
            label: "Docs",
          },
          {
            href: "https://github.com/bancolombia/async-dataflow",
            label: "GitHub",
            position: "right",
          },
        ],
      },
      footer: {
        style: "dark",
        links: [
          // {
          //   title: 'Docs',
          //   items: [
          //     {
          //       label: 'Create a Project',
          //       to: '/docs/getting-started/create-a-project',
          //     },
          //     {
          //       label: 'Entry Points',
          //       to: '/docs/getting-started/create-an-entrypoint',
          //     },
          //     {
          //       label: 'Driven Adapters',
          //       to: '/docs/getting-started/create-an-entrypoint',
          //     },
          //     {
          //       label: 'Configurations',
          //       to: '/docs/getting-started/applying-configurations',
          //     },
          //   ],
          // },
          {
            title: "Community",
            items: [
              {
                label: "Changelog",
                href: "https://github.com/bancolombia/async-dataflow/blob/master/CHANGELOG.md",
              },
              {
                label: "Contributing",
                href: "https://github.com/bancolombia/async-dataflow/blob/master/CONTRIBUTING.md",
              },
              {
                label: "License",
                href: "https://github.com/bancolombia/async-dataflow/blob/master/channel-sender/LICENSE",
              },
            ],
          },
          {
            title: "More",
            items: [
              {
                label: "Bancolombia Tech",
                href: "https://medium.com/bancolombia-tech",
              },
              {
                label: "GitHub",
                href: "https://github.com/bancolombia/async-dataflow",
              },
              {
                label: "Docker Hub | Channel Sender",
                href: "https://hub.docker.com/r/bancolombia/async-dataflow-channel-sender",
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Grupo Bancolombia.`,
      },
      prism: {
        //        additionalLanguages: ['elixir'],
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
      },
    }),
};

export default config;
