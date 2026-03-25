import { Bold, ListChecks, Search, Pin, Italic, Underline as UnderlineIcon, Strikethrough, Check, X } from "lucide-react";
import type { Editor } from "@tiptap/react";
import * as Popover from '@radix-ui/react-popover';
import { useEffect, useState } from "react";
import { useUiStore } from "@/stores";

type ToolbarProps = {
    editor: Editor | null;
    isPinned: boolean;
    onTogglePin: () => void;
    showFormatting?: boolean;
};

const TopFormatButton = ({ icon: Icon, isActive, onClick, label }: any) => (
    <button
        title={label}
        onClick={onClick}
        className={`flex size-8 items-center justify-center rounded transition-[background-color,color,transform] duration-140 ease-out active:scale-95 ${isActive ? "bg-accent/90 text-white" : "text-text hover:bg-white/10"
            }`}
    >
        <Icon size={16} strokeWidth={isActive ? 2.5 : 2} />
    </button>
);

const MenuRow = ({ label, isActive, onClick, styleClass, prefix }: any) => (
    <button
        onClick={onClick}
        className="flex w-full items-center gap-2 px-3 py-1.5 text-left outline-none transition-[background-color,color] duration-120 ease-out hover:bg-white/10"
    >
        <div className="w-4 shrink-0 flex justify-center text-text">
            {isActive && <Check size={14} strokeWidth={3} />}
        </div>
        <span className={`flex-1 text-[14px] text-text ${styleClass || "font-normal"}`}>
            {prefix && <span className="mr-1 inline-block -translate-y-[1px] font-bold text-lg">{prefix}</span>}{label}
        </span>
    </button>
);

export function Toolbar({
    editor,
    isPinned,
    onTogglePin,
    showFormatting = true,
}: ToolbarProps) {
    const [, forceUpdate] = useState(0);
    const setIsSearchModalOpen = useUiStore((state) => state.setIsSearchModalOpen);

    useEffect(() => {
        if (!editor) return;

        const syncToolbarState = () => forceUpdate((current) => current + 1);
        editor.on("transaction", syncToolbarState);
        editor.on("selectionUpdate", syncToolbarState);

        return () => {
            editor.off("transaction", syncToolbarState);
            editor.off("selectionUpdate", syncToolbarState);
        };
    }, [editor]);

    if (!editor) return null;

    return (
        <div className="flex h-[48px] shrink-0 items-center justify-between border-b border-border bg-background px-4 text-muted">
            <div className="flex items-center gap-5">
                {(showFormatting && editor) ? (
                    <>
                        <Popover.Root>
                            <Popover.Trigger asChild>
                                <button className="flex items-center justify-center rounded-md px-2 py-0.5 text-[15px] font-medium tracking-tight text-muted outline-none transition-[background-color,color,transform] duration-140 ease-out hover:bg-white/10 hover:text-text focus:outline-none active:scale-95 data-[state=open]:bg-white/10 data-[state=open]:text-text">
                                    Aa
                                </button>
                            </Popover.Trigger>

                            <Popover.Portal>
                                <Popover.Content
                                    align="end"
                                    sideOffset={8}
                                    className="z-50 w-[220px] rounded-xl border border-[#3e3e3e] bg-[#2a2a2a] py-1.5 shadow-2xl outline-none animate-in fade-in zoom-in-95 duration-200"
                                >
                                    <Popover.Arrow className="fill-[#3e3e3e] -translate-y-px" width={16} height={8} />
                                    {/* Top Bar Formats */}
                                    <div className="flex items-center justify-center gap-4 px-3 pb-2 pt-1 border-b border-[#3e3e3e] mb-1">
                                        <TopFormatButton
                                            icon={Bold}
                                            label="Bold"
                                            isActive={editor.isActive('bold')}
                                            onClick={() => editor.chain().focus().toggleBold().run()}
                                        />
                                        <TopFormatButton
                                            icon={Italic}
                                            label="Italic"
                                            isActive={editor.isActive('italic')}
                                            onClick={() => editor.chain().focus().toggleItalic().run()}
                                        />
                                        <TopFormatButton
                                            icon={UnderlineIcon}
                                            label="Underline"
                                            isActive={editor.isActive('underline')}
                                            onClick={() => editor.chain().focus().toggleUnderline().run()}
                                        />
                                        <TopFormatButton
                                            icon={Strikethrough}
                                            label="Strikethrough"
                                            isActive={editor.isActive('strike')}
                                            onClick={() => editor.chain().focus().toggleStrike().run()}
                                        />
                                    </div>

                                    {/* Block Formats */}
                                    <div className="flex flex-col mb-1">
                                        <MenuRow
                                            label="Title"
                                            styleClass="font-bold text-lg"
                                            isActive={editor.isActive('heading', { level: 1 })}
                                            onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
                                        />
                                        <MenuRow
                                            label="Heading"
                                            styleClass="font-bold text-[16px]"
                                            isActive={editor.isActive('heading', { level: 2 })}
                                            onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
                                        />
                                        <MenuRow
                                            label="Subheading"
                                            styleClass="font-bold text-[15px]"
                                            isActive={editor.isActive('heading', { level: 3 })}
                                            onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}
                                        />
                                        <MenuRow
                                            label="Body"
                                            styleClass="text-[14px]"
                                            isActive={!editor.isActive('heading') && !editor.isActive('codeBlock') && !editor.isActive('bulletList') && !editor.isActive('orderedList')}
                                            onClick={() => editor.chain().focus().setParagraph().run()}
                                        />
                                        <MenuRow
                                            label="Monospaced"
                                            styleClass="font-mono text-[13px]"
                                            isActive={editor.isActive('codeBlock')}
                                            onClick={() => editor.chain().focus().toggleCodeBlock().run()}
                                        />
                                    </div>

                                    <div className="flex flex-col">
                                        <MenuRow
                                            label="Bulleted List"
                                            prefix="•"
                                            isActive={editor.isActive('bulletList')}
                                            onClick={() => editor.chain().focus().toggleBulletList().run()}
                                        />
                                        <MenuRow
                                            label="Dashed List"
                                            prefix="–"
                                            isActive={false /* Mapping to logic omitted since tiptap default uses bullet */}
                                            onClick={() => {
                                                editor.chain().focus().toggleBulletList().run();
                                            }}
                                        />
                                        <MenuRow
                                            label="Numbered List"
                                            prefix="1."
                                            isActive={editor.isActive('orderedList')}
                                            onClick={() => editor.chain().focus().toggleOrderedList().run()}
                                        />
                                    </div>
                                </Popover.Content>
                            </Popover.Portal>
                        </Popover.Root>

                        <button
                            className={`transition-[color,transform] duration-140 ease-out hover:text-text active:scale-95 ${editor.isActive('taskList') ? "text-accent" : ""}`}
                            onClick={() => editor.chain().focus().toggleTaskList().run()}
                            title="Checklist"
                        >
                            <ListChecks size={18} />
                        </button>
                        <button
                            className={`transition-[color,transform] duration-140 ease-out hover:text-text active:scale-95 ${editor.isActive('table') ? "text-accent" : ""}`}
                            onClick={() => editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()}
                            title="Insert Table"
                        >
                        </button>
                    </>
                ) : null}
            </div>

            <div className="flex items-center gap-5">
                <button
                    className="transition-[color,transform] duration-140 ease-out hover:text-text active:scale-95"
                    title="Search Notes (Cmd+F)"
                    onClick={() => setIsSearchModalOpen(true)}
                >
                    <Search size={18} />
                </button>

                {showFormatting && (
                    <>
                        <div className="h-4 w-px bg-border" /> {/* Separator */}

                        <button
                            className={`transition-[color,transform] duration-140 ease-out hover:text-text active:scale-95 ${isPinned ? "text-accent" : ""}`}
                            onClick={onTogglePin}
                            title={isPinned ? "Unpin Note" : "Pin Note"}
                        >
                            <Pin size={18} />
                        </button>
                    </>
                )}
            </div>
        </div>
    );
}
