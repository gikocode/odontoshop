package customer

import (
	"time"

	"github.com/google/uuid"
)

type CustomerType string
type CreditStatus string

const (
	CustomerTypeRetail    CustomerType = "retail"
	CustomerTypeWholesale CustomerType = "wholesale"
	CustomerTypeCorporate CustomerType = "corporate"
)

const (
	CreditStatusNone      CreditStatus = "none"
	CreditStatusApproved  CreditStatus = "approved"
	CreditStatusSuspended CreditStatus = "suspended"
	CreditStatusRevoked   CreditStatus = "revoked"
)

type Customer struct {
	ID             uuid.UUID    `gorm:"type:uuid;primary_key;default:uuid_generate_v4()" json:"id"`
	UserID         uuid.UUID    `gorm:"type:uuid;uniqueIndex;not null" json:"user_id"`
	CustomerNumber string       `gorm:"type:varchar(20);uniqueIndex;not null" json:"customer_number"`
	CustomerType   CustomerType `gorm:"type:varchar(20);default:'retail'" json:"customer_type"`

	// Datos personales
	FirstName   *string `gorm:"type:varchar(100)" json:"first_name,omitempty"`
	LastName    *string `gorm:"type:varchar(100)" json:"last_name,omitempty"`
	CompanyName *string `gorm:"type:varchar(255)" json:"company_name,omitempty"`
	TaxID       *string `gorm:"type:varchar(50)" json:"tax_id,omitempty"`

	// Contacto
	BillingAddress  *string `gorm:"type:text" json:"billing_address,omitempty"`
	ShippingAddress *string `gorm:"type:text" json:"shipping_address,omitempty"`
	City            *string `gorm:"type:varchar(100)" json:"city,omitempty"`
	State           *string `gorm:"type:varchar(100)" json:"state,omitempty"`
	Country         string  `gorm:"type:varchar(2);default:'BE'" json:"country"`
	PostalCode      *string `gorm:"type:varchar(20)" json:"postal_code,omitempty"`

	// Crédito
	CreditStatus     CreditStatus `gorm:"type:varchar(20);default:'none'" json:"credit_status"`
	CreditLimit      float64      `gorm:"type:decimal(10,2);default:0" json:"credit_limit"`
	CurrentBalance   float64      `gorm:"type:decimal(10,2);default:0" json:"current_balance"`
	PaymentTermsDays int          `gorm:"default:0" json:"payment_terms_days"`

	// Lealtad
	LoyaltyPoints int     `gorm:"default:0" json:"loyalty_points"`
	LoyaltyTier   *string `gorm:"type:varchar(20)" json:"loyalty_tier,omitempty"`

	Notes     *string   `gorm:"type:text" json:"notes,omitempty"`
	CreatedAt time.Time `gorm:"autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"autoUpdateTime" json:"updated_at"`
}

func (Customer) TableName() string {
	return "customers"
}

// DisplayName retorna el nombre a mostrar
func (c *Customer) DisplayName() string {
	if c.CompanyName != nil && *c.CompanyName != "" {
		return *c.CompanyName
	}
	if c.FirstName != nil && c.LastName != nil {
		return *c.FirstName + " " + *c.LastName
	}
	return c.CustomerNumber
}
