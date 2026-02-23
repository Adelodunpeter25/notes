import { Bold, ListChecks, Search, Pin, Italic, Underline as UnderlineIcon, Strikethrough, Check, X } from "lucide-react";
import type { Editor } from "@tiptap/react";
import * as Popover from '@radix-ui/react-popover';
import { useSearch } from "@/hooks";

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
        className={`flex size-8 items-center justify-center rounded transition-colors ${isActive ? "bg-accent/90 text-white" : "text-text hover:bg-white/10"
            }`}
    >
        <Icon size={16} strokeWidth={isActive ? 2.5 : 2} />
    </button>
);

const MenuRow = ({ label, isActive, onClick, styleClass, prefix }: any) => (
    <button
        onClick={onClick}
        className="flex w-full items-center gap-2 px-3 py-1.5 text-left transition-colors hover:bg-white/10 outline-none"
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
    const {
        isSearchExpanded,
        searchQuery,
        handleSearchChange,
        toggleSearch,
        closeSearch,
        inputRef
    } = useSearch();

    if (!editor) return null;

    return (
        <div className="flex h-[48px] shrink-0 items-center justify-between border-b border-border bg-background px-4 text-muted">
            <div className="flex items-center gap-5">
                {(showFormatting && editor) ? (
                    <>
                        <Popover.Root>
                            <Popover.Trigger asChild>
                                <button className="flex items-center justify-center rounded-md px-2 py-0.5 text-[15px] font-medium tracking-tight text-muted transition-colors hover:bg-white/10 hover:text-text data-[state=open]:bg-white/10 data-[state=open]:text-text outline-none focus:outline-none">
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
                            className={`transition-colors hover:text-text ${editor.isActive('taskList') ? "text-accent" : ""}`}
                            onClick={() => editor.chain().focus().toggleTaskList().run()}
                            title="Checklist"
                        >
                            <ListChecks size={18} />
                        </button>
                        <button
                            className={`transition-colors hover:text-text ${editor.isActive('table') ? "text-accent" : ""}`}
                            onClick={() => editor.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()}
                            title="Insert Table"
                        >
                        </button>
                    </>
                ) : null}
            </div>

            <div className="flex items-center gap-5">
                {/* Morphing Search Bar */}
                <div className="flex items-center">
                    {isSearchExpanded ? (
                        <div className="flex items-center h-[28px] rounded-md bg-surface border border-border px-2 min-w-[200px] animate-in fade-in slide-in-from-right-2 duration-200 ease-out">
                            <Search size={14} className="text-muted shrink-0 mr-2" />
                            <input
                                ref={inputRef}
                                value={searchQuery}
                                onChange={(e) => handleSearchChange(e.target.value)}
                                onKeyDown={(e) => {
                                    if (e.key === 'Escape') {
                                        closeSearch();
                                        editor.commands.focus();
                                    }
                                }}
                                placeholder="Search all notes..."
                                className="bg-transparent text-[13px] text-text outline-none placeholder:text-muted/70 w-full min-w-0"
                            />
                            <button
                                onClick={closeSearch}
                                className="text-muted hover:text-text shrink-0 ml-1 rounded-full p-0.5 hover:bg-white/10 transition-colors"
                            >
                                <X size={14} />
                            </button>
                        </div>
                    ) : (
                        <button
                            className="transition-colors hover:text-text"
                            title="Search Notes"
                            onClick={toggleSearch}
                        >
                            <Search size={18} />
                        </button>
                    )}
                </div>

                {showFormatting && (
                    <>
                        <div className="h-4 w-px bg-border" /> {/* Separator */}

                        <button
                            className={`transition-colors hover:text-text ${isPinned ? "text-accent" : ""}`}
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
