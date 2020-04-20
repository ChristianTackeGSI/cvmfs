package lib

import (
	"fmt"

	log "github.com/sirupsen/logrus"
)

type Wish struct {
	Id          int
	InputImage  int
	OutputImage int
	CvmfsRepo   string
}

type WishFriendly struct {
	Id                int
	InputName         string
	OutputName        string
	CvmfsRepo         string
	Converted         bool
	UserInput         string
	UserOutput        string
	InputImage        *Image
	OutputImage       *Image
	ExpandedTagImages <-chan *Image
}

func CreateWish(inputImage, outputImage, cvmfsRepo, userInput, userOutput string) (wish WishFriendly, err error) {

	inputImg, err := ParseImage(inputImage)
	if err != nil {
		err = fmt.Errorf("%s | %s", err.Error(), "Error in parsing the input image")
		return
	}
	inputImg.User = userInput

	wish.InputName = inputImg.WholeName()

	outputImg, err := ParseImage(outputImage)
	if err != nil {
		err = fmt.Errorf("%s | %s", err.Error(), "Error in parsing the output image")
		return
	}
	outputImg.User = userOutput
	outputImg.IsThin = true
	wish.OutputName = outputImg.WholeName()

	wish.Id = 0
	wish.CvmfsRepo = cvmfsRepo
	wish.UserInput = userInput
	wish.UserOutput = userOutput

	iImage, errI := ParseImage(wish.InputName)
	wish.InputImage = &iImage
	wish.InputImage.User = wish.UserInput
	if errI != nil {
		wish.InputImage = nil
		err = errI
		return
	}
	expandedTagImages, errEx := iImage.ExpandWildcard()
	if errEx != nil {
		err = errEx
		LogE(err).WithFields(log.Fields{
			"input image": inputImage}).
			Error("Error in retrieving all the tags from the image")
		return
	}
	wish.ExpandedTagImages = expandedTagImages

	oImage, errO := ParseImage(wish.OutputName)
	wish.OutputImage = &oImage
	wish.OutputImage.User = wish.UserOutput
	if errO != nil {
		wish.OutputImage = nil
		err = errO
		return
	}

	return
}
