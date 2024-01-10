-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS time_series_data (
    id int NOT NULL PRIMARY KEY AUTO_INCREMENT,
    task VARCHAR(40) NOT NULL,  
    value DECIMAL(65, 0) NOT NULL,
    date VARCHAR(20) NOT NULL,
    fee_token_address varchar(42) DEFAULT "",
    tier INT DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE key `task_date` (`task`, `date`, `tier`, `fee_token_address`)
);

-- +goose StatementEnd
-- +goose Down
-- +goose StatementBegin
DROP TABLE time_series_data;
-- +goose StatementEnd
