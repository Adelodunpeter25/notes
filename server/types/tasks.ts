export type Task = {
  id: string;
  userId: string;
  title: string;
  description: string;
  isCompleted: boolean;
  dueDate?: Date | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt?: Date | null;
};

export type CreateTaskPayload = {
  title: string;
  description?: string;
  dueDate?: string;
};

export type UpdateTaskPayload = {
  title?: string;
  description?: string;
  isCompleted?: boolean;
  dueDate?: string;
};
