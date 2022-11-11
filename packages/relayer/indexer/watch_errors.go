package indexer

import log "github.com/sirupsen/logrus"

func (svc *Service) watchErrors() {
	for {
		select {
		case err := <-svc.errChan:
			log.Infof("svc.watchErrors: %v", err)
		}
	}
}
