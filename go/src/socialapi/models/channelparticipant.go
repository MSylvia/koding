package models

import (
	"errors"
	"time"
)

type ChannelParticipant struct {
	// unique identifier of the channel
	Id int64

	// Id of the channel
	ChannelId int64

	// Id of the account
	AccountId int64

	// Status of the participant in the channel
	Status int

	// date of the user's last access to regarding channel
	LastSeenAt time.Time

	// Creation date of the channel channel participant
	CreatedAt time.Time

	// Modification date of the channel participant's status
	UpdatedAt time.Time

	//Base model operations
	m Model
}

// here is why i did this not-so-good constants
// https://code.google.com/p/go/issues/detail?id=359
const (
	ChannelParticipant_STATUS_ACTIVE int = iota
	ChannelParticipant_STATUS_LEFT
	ChannelParticipant_STATUS_REQUEST_PENDING
)

func NewChannelParticipant() *ChannelParticipant {
	return &ChannelParticipant{}
}

func (c *ChannelParticipant) GetId() int64 {
	return c.Id
}

func (c *ChannelParticipant) TableName() string {
	return "channel_participant"
}

func (c *ChannelParticipant) Self() Modellable {
	return c
}

func (c *ChannelParticipant) BeforeSave() {
	c.LastSeenAt = time.Now().UTC()
}

func (c *ChannelParticipant) BeforeUpdate() {
	c.LastSeenAt = time.Now().UTC()
}

func (c *ChannelParticipant) Create() error {
	return c.m.Create(c)
}

func (c *ChannelParticipant) Update() error {
	return c.m.Update(c)
}

func (c *ChannelParticipant) FetchParticipant() error {

	if c.ChannelId == 0 {
		return errors.New("ChannelId is not set")
	}

	if c.AccountId == 0 {
		return errors.New("AccountId is not set")
	}

	selector := map[string]interface{}{
		"channel_id": c.ChannelId,
		"account_id": c.AccountId,
		"status":     ChannelParticipant_STATUS_ACTIVE,
	}

	err := c.m.Some(c, c, selector)
	if err != nil {
		return err
	}

	return nil
}

func (c *ChannelParticipant) Delete() error {
	return c.m.UpdatePartial(c,
		Partial{
			"account_id": c.AccountId,
			"channel_id": c.ChannelId,
		},
		Partial{
			"status": ChannelParticipant_STATUS_LEFT,
		},
	)
}

func (c *ChannelParticipant) List() ([]ChannelParticipant, error) {
	var participants []ChannelParticipant

	if c.ChannelId == 0 {
		return participants, errors.New("ChannelId is not set")
	}

	selector := map[string]interface{}{
		"channel_id": c.ChannelId,
		"status":     ChannelParticipant_STATUS_ACTIVE,
	}

	err := c.m.Some(c, &participants, selector)
	if err != nil {
		return nil, err
	}

	return participants, nil
}
