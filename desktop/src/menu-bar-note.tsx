import React from "react";
import ReactDOM from "react-dom/client";

import { MenuBarNote } from "@/components/menu-bar-note/MenuBarNote";
import "@/styles.css";

document.documentElement.classList.add("dark");

ReactDOM.createRoot(document.getElementById("menu-bar-note-root")!).render(
  <React.StrictMode>
    <MenuBarNote />
  </React.StrictMode>,
);
