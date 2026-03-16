package employee

import (
	"time"

	"github.com/google/uuid"
)

type EmploymentStatus string

const (
	EmploymentStatusActive     EmploymentStatus = "active"
	EmploymentStatusOnLeave    EmploymentStatus = "on_leave"
	EmploymentStatusTerminated EmploymentStatus = "terminated"
	EmploymentStatusResigned   EmploymentStatus = "resigned"
)

type Employee struct {
	ID               uuid.UUID        `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	UserID           uuid.UUID        `gorm:"type:uuid;uniqueIndex;not null" json:"user_id"`
	EmployeeNumber   string           `gorm:"type:varchar(20);uniqueIndex;not null" json:"employee_number"`
	FirstName        string           `gorm:"type:varchar(100);not null" json:"first_name"`
	LastName         string           `gorm:"type:varchar(100);not null" json:"last_name"`
	Position         *string          `gorm:"type:varchar(100)" json:"position,omitempty"`
	Department       *string          `gorm:"type:varchar(100)" json:"department,omitempty"`
	HireDate         time.Time        `gorm:"type:date;not null" json:"hire_date"`
	EmploymentStatus EmploymentStatus `gorm:"type:varchar(20);default:'active'" json:"employment_status"`
	Salary           *float64         `gorm:"type:decimal(10,2)" json:"-"` // Sensible, no exponer
	SupervisorID     *uuid.UUID       `gorm:"type:uuid" json:"supervisor_id,omitempty"`
	CreatedAt        time.Time        `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt        time.Time        `gorm:"autoUpdateTime" json:"updated_at"`
}

func (Employee) TableName() string {
	return "employees"
}

// FullName retorna el nombre completo
func (e *Employee) FullName() string {
	return e.FirstName + " " + e.LastName
}
