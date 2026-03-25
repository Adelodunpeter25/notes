export type Task = {
  id: string;
  userId?: string;
  title: string;
  description: string;
  isCompleted: boolean;
  dueDate?: string;
  createdAt?: string;
  updatedAt?: string;
  deletedAt?: string;
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
