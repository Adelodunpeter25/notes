package services

import (
	"errors"
	"strings"

	"gorm.io/gorm"
	"notes/server/internal/models"
	"notes/server/internal/schemas"
)

var ErrTaskNotFound = errors.New("task not found")

type TaskService interface {
	Create(userID string, payload schemas.CreateTaskRequest) (schemas.TaskResponse, error)
	List(userID string, query string) ([]schemas.TaskResponse, error)
	Update(userID, taskID string, payload schemas.UpdateTaskRequest) (schemas.TaskResponse, error)
	Delete(userID, taskID string) error
}

type GormTaskService struct {
	db *gorm.DB
}

func NewGormTaskService(conn *gorm.DB) *GormTaskService {
	return &GormTaskService{db: conn}
}

func (service *GormTaskService) Create(userID string, payload schemas.CreateTaskRequest) (schemas.TaskResponse, error) {
	title := strings.TrimSpace(payload.Title)
	if title == "" {
		title = "Untitled"
	}

	task := models.Task{
		UserID:      userID,
		Title:       title,
		Description: payload.Description,
		IsCompleted: payload.IsCompleted,
		DueDate:     payload.DueDate,
	}
	if err := service.db.Create(&task).Error; err != nil {
		return schemas.TaskResponse{}, err
	}

	return mapTaskResponse(task), nil
}

func (service *GormTaskService) List(userID string, query string) ([]schemas.TaskResponse, error) {
	builder := service.db.Where("user_id = ?", userID)

	trimmedQuery := strings.TrimSpace(query)
	if trimmedQuery != "" {
		like := "%" + trimmedQuery + "%"
		builder = builder.Where("title ILIKE ? OR description ILIKE ?", like, like)
	}

	var tasks []models.Task
	if err := builder.Order("updated_at DESC").Find(&tasks).Error; err != nil {
		return nil, err
	}

	response := make([]schemas.TaskResponse, 0, len(tasks))
	for _, task := range tasks {
		response = append(response, mapTaskResponse(task))
	}

	return response, nil
}

func (service *GormTaskService) Update(userID, taskID string, payload schemas.UpdateTaskRequest) (schemas.TaskResponse, error) {
	var task models.Task
	if err := service.db.Where("id = ? AND user_id = ?", taskID, userID).First(&task).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return schemas.TaskResponse{}, ErrTaskNotFound
		}
		return schemas.TaskResponse{}, err
	}

	if payload.Title != nil {
		title := strings.TrimSpace(*payload.Title)
		if title == "" {
			title = "Untitled"
		}
		task.Title = title
	}
	if payload.Description != nil {
		task.Description = *payload.Description
	}
	if payload.IsCompleted != nil {
		task.IsCompleted = *payload.IsCompleted
	}
	if payload.DueDate != nil {
		task.DueDate = payload.DueDate
	}

	if err := service.db.Save(&task).Error; err != nil {
		return schemas.TaskResponse{}, err
	}

	return mapTaskResponse(task), nil
}

func (service *GormTaskService) Delete(userID, taskID string) error {
	result := service.db.Where("id = ? AND user_id = ?", taskID, userID).Delete(&models.Task{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return ErrTaskNotFound
	}
	return nil
}

func mapTaskResponse(task models.Task) schemas.TaskResponse {
	return schemas.TaskResponse{
		ID:          task.ID,
		Title:       task.Title,
		Description: task.Description,
		IsCompleted: task.IsCompleted,
		DueDate:     task.DueDate,
		CreatedAt:   task.CreatedAt,
		UpdatedAt:   task.UpdatedAt,
	}
}
